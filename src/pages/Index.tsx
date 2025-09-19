
import React from 'react';
import { useAuth } from '@/contexts/AuthContext';
import AuthPage from '@/components/Auth/AuthPage';
import Dashboard from './Dashboard';

const Index = () => {
  const { user, profile, loading } = useAuth();

  if (loading) {
    return (
      <div className="min-h-screen flex items-center justify-center">
        <div className="animate-spin rounded-full h-8 w-8 border-b-2 border-primary"></div>
      </div>
    );
  }

  // Show auth page if no user
  if (!user) {
    return <AuthPage />;
  }

  // Show dashboard if user is logged in and has profile
  if (user && profile) {
    return <Dashboard />;
  }

  // Show loading if user exists but profile is still loading
  return (
    <div className="min-h-screen flex items-center justify-center">
      <div className="text-center">
        <div className="animate-spin rounded-full h-8 w-8 border-b-2 border-primary mx-auto mb-4"></div>
        <p className="text-muted-foreground">Loading your profile...</p>
      </div>
    </div>
  );
};

export default Index;
