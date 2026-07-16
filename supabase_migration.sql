-- ══════════════════════════════════════════════════════
-- Supabase Migration: Gym App + pgvector
-- Ejecutar en SQL Editor de Supabase (TODO JUNTO)
-- ══════════════════════════════════════════════════════

-- [1] Extensión pgvector
CREATE EXTENSION IF NOT EXISTS vector;

-- [2] Tabla de ejercicios (con columna embedding)
CREATE TABLE IF NOT EXISTS exercises (
  id                TEXT PRIMARY KEY,
  name              TEXT NOT NULL,
  name_es           TEXT DEFAULT '',
  category          TEXT,
  body_part         TEXT,
  equipment         TEXT,
  instructions_es   TEXT DEFAULT '',
  muscle_group      TEXT,
  secondary_muscles JSONB DEFAULT '[]',
  target            TEXT,
  image             TEXT,
  gif_url           TEXT,
  media_id          TEXT,
  attribution       TEXT,
  embedding         vector(384),
  created_at        TIMESTAMPTZ DEFAULT NOW()
);

-- Índices
CREATE INDEX IF NOT EXISTS idx_exercises_category ON exercises(category);
CREATE INDEX IF NOT EXISTS idx_exercises_equipment ON exercises(equipment);
CREATE INDEX IF NOT EXISTS idx_exercises_target ON exercises(target);

-- [3] Tabla de perfiles
CREATE TABLE IF NOT EXISTS profiles (
  id            UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  gender        TEXT DEFAULT 'male',
  age           INT DEFAULT 25,
  weight_kg     REAL DEFAULT 70,
  height_cm     REAL DEFAULT 170,
  fitness_level TEXT DEFAULT 'beginner',
  goal          TEXT DEFAULT 'general',
  created_at    TIMESTAMPTZ DEFAULT NOW(),
  updated_at    TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users can read own profile" ON profiles FOR SELECT USING (auth.uid() = id);
CREATE POLICY "Users can insert own profile" ON profiles FOR INSERT WITH CHECK (auth.uid() = id);
CREATE POLICY "Users can update own profile" ON profiles FOR UPDATE USING (auth.uid() = id);

-- [4] Tabla de rutinas
CREATE TABLE IF NOT EXISTS routines (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id     UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  created_at  TIMESTAMPTZ DEFAULT NOW(),
  days        JSONB NOT NULL DEFAULT '{}'
);

ALTER TABLE routines ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users can read own routines" ON routines FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "Users can insert own routines" ON routines FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Users can update own routines" ON routines FOR UPDATE USING (auth.uid() = user_id);
CREATE POLICY "Users can delete own routines" ON routines FOR DELETE USING (auth.uid() = user_id);

-- [5] Tabla de favoritos
CREATE TABLE IF NOT EXISTS favorites (
  user_id     UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  exercise_id TEXT NOT NULL REFERENCES exercises(id) ON DELETE CASCADE,
  created_at  TIMESTAMPTZ DEFAULT NOW(),
  PRIMARY KEY (user_id, exercise_id)
);

ALTER TABLE favorites ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users can read own favorites" ON favorites FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "Users can insert own favorites" ON favorites FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Users can delete own favorites" ON favorites FOR DELETE USING (auth.uid() = user_id);

-- [6] Trigger para crear perfil al registrarse
CREATE OR REPLACE FUNCTION handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO public.profiles (id) VALUES (NEW.id);
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION handle_new_user();

-- [7] Función RPC: búsqueda semántica con vectores (RAG)
CREATE OR REPLACE FUNCTION search_exercises(
  query_embedding vector(384),
  match_limit INT DEFAULT 30,
  p_category TEXT DEFAULT NULL,
  p_equipment TEXT DEFAULT NULL
)
RETURNS TABLE(
  id TEXT,
  name TEXT,
  name_es TEXT,
  category TEXT,
  equipment TEXT,
  target TEXT,
  muscle_group TEXT,
  secondary_muscles JSONB,
  instructions_es TEXT,
  image TEXT,
  gif_url TEXT,
  similarity REAL
) AS $$
BEGIN
  RETURN QUERY
  SELECT
    e.id, e.name, e.name_es, e.category, e.equipment, e.target,
    e.muscle_group, e.secondary_muscles, e.instructions_es,
    e.image, e.gif_url,
    (1 - (e.embedding <=> query_embedding))::REAL AS similarity
  FROM exercises e
  WHERE
    (p_category IS NULL OR e.category = p_category)
    AND (p_equipment IS NULL OR e.equipment = p_equipment)
  ORDER BY e.embedding <=> query_embedding
  LIMIT match_limit;
END;
$$ LANGUAGE plpgsql;
