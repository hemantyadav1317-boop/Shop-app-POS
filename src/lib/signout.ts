import { supabase } from "@/integrations/supabase/client";

export async function signOutAndRedirect() {
  try {
    await supabase.auth.signOut();
  } finally {
    window.location.replace("/");
  }
}
