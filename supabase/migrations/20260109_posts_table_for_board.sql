-- 掲示板用のpostsテーブルを作成
CREATE TABLE IF NOT EXISTS posts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    content TEXT NOT NULL CHECK (char_length(content) <= 1000),
    image_path TEXT,  -- Storageのオブジェクトパス（画像なしの場合はNULL）
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- コメント追加
COMMENT ON TABLE posts IS 'ユーザー掲示板の投稿';
COMMENT ON COLUMN posts.content IS '投稿のテキスト内容（最大1000文字）';
COMMENT ON COLUMN posts.image_path IS 'Storage内の画像パス（user-photosバケット）';

-- インデックス作成（新しい順で表示するため）
CREATE INDEX idx_posts_created_at_desc ON posts (created_at DESC);
CREATE INDEX idx_posts_user_id ON posts (user_id);

-- RLS有効化
ALTER TABLE posts ENABLE ROW LEVEL SECURITY;

-- RLSポリシー：全ユーザーがすべての投稿を閲覧可能
CREATE POLICY "posts_select_all" ON posts
    FOR SELECT
    TO authenticated
    USING (true);

-- RLSポリシー：認証ユーザーは自分の投稿を作成可能
CREATE POLICY "posts_insert_own" ON posts
    FOR INSERT
    TO authenticated
    WITH CHECK (auth.uid() = user_id);

-- RLSポリシー：自分の投稿のみ削除可能
CREATE POLICY "posts_delete_own" ON posts
    FOR DELETE
    TO authenticated
    USING (auth.uid() = user_id);

-- user_photosテーブルを削除（不要になるため）
DROP TABLE IF EXISTS user_photos CASCADE;

