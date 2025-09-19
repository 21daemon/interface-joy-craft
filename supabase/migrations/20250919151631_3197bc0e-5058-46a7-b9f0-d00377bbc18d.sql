-- Create user role enum
CREATE TYPE public.user_role AS ENUM ('student', 'group_leader', 'mentor', 'local_guardian', 'hod', 'alumni');

-- Create profiles table
CREATE TABLE public.profiles (
  id UUID NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID NOT NULL UNIQUE REFERENCES auth.users(id) ON DELETE CASCADE,
  email TEXT NOT NULL,
  name TEXT NOT NULL,
  role user_role NOT NULL,
  group_id UUID,
  mentor_id UUID,
  local_guardian_id UUID,
  approved BOOLEAN NOT NULL DEFAULT false,
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
  updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now()
);

-- Create groups table
CREATE TABLE public.groups (
  id UUID NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  name TEXT NOT NULL,
  leader_id UUID REFERENCES public.profiles(id),
  mentor_id UUID REFERENCES public.profiles(id),
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
  updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now()
);

-- Create group members junction table
CREATE TABLE public.group_members (
  id UUID NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  group_id UUID NOT NULL REFERENCES public.groups(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  joined_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
  UNIQUE(group_id, user_id)
);

-- Add foreign key constraints to profiles for group_id
ALTER TABLE public.profiles 
ADD CONSTRAINT fk_profiles_group_id 
FOREIGN KEY (group_id) REFERENCES public.groups(id);

ALTER TABLE public.profiles 
ADD CONSTRAINT fk_profiles_mentor_id 
FOREIGN KEY (mentor_id) REFERENCES public.profiles(id);

ALTER TABLE public.profiles 
ADD CONSTRAINT fk_profiles_local_guardian_id 
FOREIGN KEY (local_guardian_id) REFERENCES public.profiles(id);

-- Enable Row Level Security
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.groups ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.group_members ENABLE ROW LEVEL SECURITY;

-- Create security definer function to get user role
CREATE OR REPLACE FUNCTION public.get_user_role(user_uuid UUID)
RETURNS user_role
LANGUAGE SQL
SECURITY DEFINER
STABLE
SET search_path = public
AS $$
  SELECT role FROM public.profiles WHERE user_id = user_uuid;
$$;

-- RLS Policies for profiles
CREATE POLICY "Users can view their own profile" 
ON public.profiles FOR SELECT 
USING (auth.uid() = user_id);

CREATE POLICY "Users can update their own profile" 
ON public.profiles FOR UPDATE 
USING (auth.uid() = user_id);

CREATE POLICY "HOD can view all profiles" 
ON public.profiles FOR SELECT 
USING (public.get_user_role(auth.uid()) = 'hod');

CREATE POLICY "Mentors can view their mentees" 
ON public.profiles FOR SELECT 
USING (
  public.get_user_role(auth.uid()) = 'mentor' AND 
  mentor_id = (SELECT id FROM public.profiles WHERE user_id = auth.uid())
);

CREATE POLICY "Local guardians can view their students" 
ON public.profiles FOR SELECT 
USING (
  public.get_user_role(auth.uid()) = 'local_guardian' AND 
  local_guardian_id = (SELECT id FROM public.profiles WHERE user_id = auth.uid())
);

-- RLS Policies for groups
CREATE POLICY "Users can view groups they belong to" 
ON public.groups FOR SELECT 
USING (
  id IN (
    SELECT group_id FROM public.group_members 
    WHERE user_id = (SELECT id FROM public.profiles WHERE user_id = auth.uid())
  )
);

CREATE POLICY "Group leaders can update their groups" 
ON public.groups FOR UPDATE 
USING (leader_id = (SELECT id FROM public.profiles WHERE user_id = auth.uid()));

CREATE POLICY "HOD can view all groups" 
ON public.groups FOR SELECT 
USING (public.get_user_role(auth.uid()) = 'hod');

-- RLS Policies for group_members
CREATE POLICY "Users can view group memberships" 
ON public.group_members FOR SELECT 
USING (
  user_id = (SELECT id FROM public.profiles WHERE user_id = auth.uid()) OR
  group_id IN (
    SELECT group_id FROM public.group_members 
    WHERE user_id = (SELECT id FROM public.profiles WHERE user_id = auth.uid())
  )
);

-- Function to handle new user registration
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  INSERT INTO public.profiles (user_id, email, name, role)
  VALUES (
    NEW.id,
    NEW.email,
    COALESCE(NEW.raw_user_meta_data ->> 'name', NEW.email),
    COALESCE((NEW.raw_user_meta_data ->> 'role')::user_role, 'student')
  );
  RETURN NEW;
END;
$$;

-- Trigger for automatic profile creation
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- Function to update timestamps
CREATE OR REPLACE FUNCTION public.update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SET search_path = public;

-- Triggers for updated_at
CREATE TRIGGER update_profiles_updated_at
  BEFORE UPDATE ON public.profiles
  FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

CREATE TRIGGER update_groups_updated_at
  BEFORE UPDATE ON public.groups
  FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();