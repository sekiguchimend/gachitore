-- postsテーブルからuser_profilesへの外部キー制約を追加
-- これによりPostgRESTでJOINクエリが可能になる
ALTER TABLE posts 
ADD CONSTRAINT posts_user_id_user_profiles_fkey 
FOREIGN KEY (user_id) REFERENCES user_profiles(user_id) ON DELETE CASCADE;

