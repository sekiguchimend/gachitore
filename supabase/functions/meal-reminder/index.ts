import "jsr:@supabase/functions-js/edge-runtime.d.ts";

import postgres from "https://deno.land/x/postgresjs@v3.4.5/mod.js";

type MealType = "breakfast" | "lunch" | "dinner";

const ALLOWED_MEAL_TYPES: MealType[] = ["breakfast", "lunch", "dinner"];

function requireEnv(name: string): string {
  const v = Deno.env.get(name);
  if (!v) throw new Error(`Missing env: ${name}`);
  return v;
}

// This function writes directly to DB (bypasses RLS). Never expose it publicly.
// Require an internal secret header for manual invocations.
const MEAL_REMINDER_SECRET = Deno.env.get("MEAL_REMINDER_SECRET") ?? "";

const sql = postgres(requireEnv("SUPABASE_DB_URL"));

function buildReminderMessage(mealType: MealType): string {
  switch (mealType) {
    case "breakfast":
      return [
        "おはようございます。朝食の記録がまだのようです。",
        "食べた場合は、食事ページからサッと入力してみてくださいね。",
        "もし朝食を抜いた場合も、無理せず体調優先でOKです。",
      ].join("\n");
    case "lunch":
      return [
        "こんにちは。お昼の記録がまだ見当たりません。",
        "今日はお昼は抜きでしたか？",
        "食べた場合は、あとからでも大丈夫なので食事記録に入れてみてください。",
      ].join("\n");
    case "dinner":
      return [
        "こんばんは。夕食の記録がまだのようです。",
        "食べたら忘れないうちに入力してみましょう。",
        "もしこれから夕食なら、食べる予定が決まったらメモ代わりに入れておくのもおすすめです。",
      ].join("\n");
  }
}

Deno.serve(async (req) => {
  try {
    if (req.method !== "POST") {
      return new Response("Method Not Allowed", { status: 405 });
    }

    if (!MEAL_REMINDER_SECRET) {
      return new Response(
        JSON.stringify({ ok: false, error: "Server not configured" }),
        { status: 503, headers: { "Content-Type": "application/json" } },
      );
    }

    const provided = req.headers.get("x-meal-reminder-secret") ?? "";
    if (provided !== MEAL_REMINDER_SECRET) {
      return new Response(JSON.stringify({ ok: false, error: "Forbidden" }), {
        status: 403,
        headers: { "Content-Type": "application/json" },
      });
    }

    const contentType = req.headers.get("content-type") ?? "";
    if (!contentType.includes("application/json")) {
      return new Response("Bad Request: expected application/json", {
        status: 400,
      });
    }

    const body = (await req.json()) as { meal_type?: string };
    const mealType = body.meal_type;

    if (!mealType || !ALLOWED_MEAL_TYPES.includes(mealType as MealType)) {
      return new Response(
        JSON.stringify({
          error: "invalid meal_type",
          allowed: ALLOWED_MEAL_TYPES,
        }),
        { status: 400, headers: { "Content-Type": "application/json" } },
      );
    }

    const reminderText = buildReminderMessage(mealType as MealType);

    // Use JST for the 'date' column (the DB server is typically UTC).
    const [{ today }]: Array<{ today: string }> = await sql`
      select (now() at time zone 'Asia/Tokyo')::date::text as today;
    `;

    // Insert reminders in a single SQL statement (idempotent via unique constraint).
    const insertedRows = await sql`
      with t as (
        select (now() at time zone 'Asia/Tokyo')::date as today
      )
      insert into public.ai_inbox_messages (user_id, date, kind, meal_type, content)
      select
        up.user_id,
        t.today,
        'meal_reminder',
        ${mealType}::text,
        ${reminderText}::text
      from public.user_profiles up
      cross join t
      left join public.meals m
        on m.user_id = up.user_id
        and m.date = t.today
        and m.meal_type = ${mealType}::text
      where
        up.onboarding_completed = true
        and m.id is null
      on conflict (user_id, date, kind, meal_type)
      do nothing
      returning user_id;
    `;

    return new Response(
      JSON.stringify({
        ok: true,
        date_jst: today,
        meal_type: mealType,
        inserted_count: insertedRows.length,
      }),
      { status: 200, headers: { "Content-Type": "application/json" } },
    );
  } catch (e) {
    const message = e instanceof Error ? e.message : String(e);
    return new Response(
      JSON.stringify({ ok: false, error: message }),
      { status: 500, headers: { "Content-Type": "application/json" } },
    );
  }
});


