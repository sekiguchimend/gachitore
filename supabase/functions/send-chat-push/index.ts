import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "jsr:@supabase/supabase-js@2";

type PushRequest = {
  title?: string;
  body: string;
  data?: Record<string, string>;
};

function requireEnv(name: string): string {
  const v = Deno.env.get(name);
  if (!v) throw new Error(`Missing env: ${name}`);
  return v;
}

function createSupabaseFromRequest(req: Request) {
  const supabaseUrl = requireEnv("SUPABASE_URL").replace(/\/+$/g, "");
  const anonKey = requireEnv("SUPABASE_ANON_KEY");
  const authHeader = req.headers.get("Authorization") ?? "";

  return createClient(supabaseUrl, anonKey, {
    auth: { persistSession: false },
    global: {
      headers: {
        Authorization: authHeader,
      },
    },
  });
}

function getServiceAccount() {
  const rawJson = Deno.env.get("FIREBASE_SERVICE_ACCOUNT_JSON");
  if (rawJson) {
    const parsed = JSON.parse(rawJson) as {
      project_id: string;
      client_email: string;
      private_key: string;
    };
    return {
      projectId: parsed.project_id,
      clientEmail: parsed.client_email,
      privateKey: parsed.private_key,
    };
  }

  return {
    projectId: requireEnv("FIREBASE_PROJECT_ID"),
    clientEmail: requireEnv("FIREBASE_CLIENT_EMAIL"),
    privateKey: requireEnv("FIREBASE_PRIVATE_KEY"),
  };
}

async function getGoogleAccessToken(): Promise<{ access_token: string; expires_in: number }> {
  // Service account JWT flow (OAuth2)
  // https://oauth2.googleapis.com/token
  const { projectId: _pid, clientEmail, privateKey } = getServiceAccount();

  const now = Math.floor(Date.now() / 1000);
  const header = { alg: "RS256", typ: "JWT" };
  const payload = {
    iss: clientEmail,
    scope: "https://www.googleapis.com/auth/firebase.messaging",
    aud: "https://oauth2.googleapis.com/token",
    iat: now,
    exp: now + 60 * 55,
  };

  // Minimal RS256 signing using WebCrypto
  const enc = new TextEncoder();
  const toB64Url = (u8: Uint8Array) =>
    btoa(String.fromCharCode(...u8))
      .replace(/\+/g, "-")
      .replace(/\//g, "_")
      .replace(/=+$/g, "");

  const headerB64 = toB64Url(enc.encode(JSON.stringify(header)));
  const payloadB64 = toB64Url(enc.encode(JSON.stringify(payload)));
  const signingInput = `${headerB64}.${payloadB64}`;

  // Convert PEM to CryptoKey
  const pem = privateKey.replace(/\\n/g, "\n");
  const pemBody = pem
    .replace("-----BEGIN PRIVATE KEY-----", "")
    .replace("-----END PRIVATE KEY-----", "")
    .replace(/\s+/g, "");
  const der = Uint8Array.from(atob(pemBody), (c) => c.charCodeAt(0)).buffer;

  const key = await crypto.subtle.importKey(
    "pkcs8",
    der,
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
    false,
    ["sign"],
  );

  const sig = await crypto.subtle.sign(
    { name: "RSASSA-PKCS1-v1_5" },
    key,
    enc.encode(signingInput),
  );

  const jwt = `${signingInput}.${toB64Url(new Uint8Array(sig))}`;

  const form = new URLSearchParams();
  form.set("grant_type", "urn:ietf:params:oauth:grant-type:jwt-bearer");
  form.set("assertion", jwt);

  const resp = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: form.toString(),
  });

  if (!resp.ok) {
    const t = await resp.text();
    throw new Error(`Failed to get access token: ${resp.status} ${t}`);
  }

  return await resp.json();
}

async function fetchUserTokens(userId: string, authHeader: string): Promise<string[]> {
  const supabaseUrl = requireEnv("SUPABASE_URL").replace(/\/+$/g, "");
  const anonKey = requireEnv("SUPABASE_ANON_KEY");

  const url =
    `${supabaseUrl}/rest/v1/user_push_tokens?select=token&user_id=eq.${encodeURIComponent(userId)}`;

  const resp = await fetch(url, {
    headers: {
      apikey: anonKey,
      Authorization: authHeader,
    },
  });

  if (!resp.ok) {
    const t = await resp.text();
    throw new Error(`Failed to fetch tokens: ${resp.status} ${t}`);
  }

  const rows = (await resp.json()) as Array<{ token: string }>;
  return rows.map((r) => r.token).filter((t) => t && t.length > 0);
}

async function sendFcm(token: string, title: string, body: string, data?: Record<string, string>) {
  const { projectId } = getServiceAccount();
  const { access_token } = await getGoogleAccessToken();

  const endpoint = `https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`;
  const payload = {
    message: {
      token,
      notification: { title, body },
      data: data ?? {},
    },
  };

  const resp = await fetch(endpoint, {
    method: "POST",
    headers: {
      Authorization: `Bearer ${access_token}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify(payload),
  });

  if (!resp.ok) {
    const t = await resp.text();
    throw new Error(`FCM send failed: ${resp.status} ${t}`);
  }
}

Deno.serve(async (req) => {
  try {
    if (req.method !== "POST") {
      return new Response("Method Not Allowed", { status: 405 });
    }

    const authHeader = req.headers.get("Authorization");
    if (!authHeader || !authHeader.startsWith("Bearer ")) {
      return new Response(JSON.stringify({ ok: false, error: "Unauthorized" }), {
        status: 401,
        headers: { "Content-Type": "application/json" },
      });
    }

    // Verify token by asking Supabase Auth, then use returned user.id as source of truth.
    const supabase = createSupabaseFromRequest(req);
    const { data: userData, error: userErr } = await supabase.auth.getUser();
    const userId = userData?.user?.id ?? null;
    if (userErr || !userId) {
      return new Response(JSON.stringify({ ok: false, error: "Unauthorized" }), {
        status: 401,
        headers: { "Content-Type": "application/json" },
      });
    }

    const contentType = req.headers.get("content-type") ?? "";
    if (!contentType.includes("application/json")) {
      return new Response("Bad Request: expected application/json", { status: 400 });
    }

    const body = (await req.json()) as PushRequest;
    if (!body.body || body.body.trim().length === 0) {
      return new Response(JSON.stringify({ ok: false, error: "body is required" }), {
        status: 400,
        headers: { "Content-Type": "application/json" },
      });
    }

    const tokens = await fetchUserTokens(userId, authHeader);
    if (tokens.length === 0) {
      return new Response(JSON.stringify({ ok: true, sent: 0, reason: "no_tokens" }), {
        status: 200,
        headers: { "Content-Type": "application/json" },
      });
    }

    const title = body.title ?? "ガチトレ";
    const msgBody = body.body.length > 180 ? `${body.body.slice(0, 180)}…` : body.body;

    const results: Array<{ ok: boolean; error?: string }> = [];
    for (const t of tokens) {
      try {
        await sendFcm(t, title, msgBody, body.data);
        results.push({ ok: true });
      } catch (e) {
        const message = e instanceof Error ? e.message : String(e);
        results.push({ ok: false, error: message });
      }
    }

    const sent = results.filter((r) => r.ok).length;
    const failed = results.length - sent;
    return new Response(JSON.stringify({ ok: true, sent, failed }), {
      status: 200,
      headers: { "Content-Type": "application/json" },
    });
  } catch (e) {
    const message = e instanceof Error ? e.message : String(e);
    return new Response(JSON.stringify({ ok: false, error: message }), {
      status: 500,
      headers: { "Content-Type": "application/json" },
    });
  }
});


