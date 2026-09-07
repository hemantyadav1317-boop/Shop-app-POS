CREATE OR REPLACE FUNCTION public.is_shop_owner(_shop_id uuid)
RETURNS boolean
LANGUAGE sql
STABLE SECURITY DEFINER
SET search_path TO 'public'
AS $$
  SELECT EXISTS (SELECT 1 FROM public.shops s WHERE s.id = _shop_id AND s.owner_id = auth.uid());
$$;

REVOKE ALL ON FUNCTION public.is_shop_owner(uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.is_shop_owner(uuid) TO authenticated;

DROP POLICY IF EXISTS "self join as owner" ON public.shop_members;
CREATE POLICY "self join as owner" ON public.shop_members
FOR INSERT TO authenticated
WITH CHECK (
  ((user_id = auth.uid()) AND public.is_shop_owner(shop_id))
  OR public.has_shop_role(shop_id, ARRAY['owner'::public.shop_role, 'manager'::public.shop_role])
);

DELETE FROM public.shops s
WHERE NOT EXISTS (SELECT 1 FROM public.shop_members m WHERE m.shop_id = s.id);