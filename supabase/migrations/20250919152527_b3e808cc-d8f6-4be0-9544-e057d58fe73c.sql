-- Drop all existing policies on profiles table to prevent conflicts
DROP POLICY IF EXISTS "Users can view their own profile" ON public.profiles;
DROP POLICY IF EXISTS "Users can update their own profile" ON public.profiles;
DROP POLICY IF EXISTS "HOD can view all profiles" ON public.profiles;
DROP POLICY IF EXISTS "Mentors can view their mentees" ON public.profiles;
DROP POLICY IF EXISTS "Local guardians can view their students" ON public.profiles;

-- Drop the problematic function
DROP FUNCTION IF EXISTS public.get_user_role(UUID);

-- Create simple, non-recursive policies
CREATE POLICY "Enable read access for users to their own profile" 
ON public.profiles FOR SELECT 
USING (auth.uid() = user_id);

CREATE POLICY "Enable update access for users to their own profile" 
ON public.profiles FOR UPDATE 
USING (auth.uid() = user_id);

CREATE POLICY "Enable insert access for authenticated users" 
ON public.profiles FOR INSERT 
WITH CHECK (auth.uid() = user_id);

-- Create a policy for service role to work with triggers
CREATE POLICY "Enable insert for service role" 
ON public.profiles FOR INSERT 
TO service_role 
WITH CHECK (true);

-- For now, let's make profiles readable by authenticated users
-- We'll implement proper role-based access later without recursion
CREATE POLICY "Enable read access for authenticated users" 
ON public.profiles FOR SELECT 
TO authenticated
USING (true);