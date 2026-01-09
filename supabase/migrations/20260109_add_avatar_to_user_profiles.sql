-- user_profilesテーブルにアバター画像パスを追加
ALTER TABLE user_profiles 
ADD COLUMN avatar_path TEXT;

-- コメント追加
COMMENT ON COLUMN user_profiles.avatar_path IS 'プロフィール画像のStorageパス（user-photosバケット）';

