GRANT EXECUTE ON FUNCTION public.is_shop_member(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.has_shop_role(uuid, public.shop_role[]) TO authenticated;
GRANT EXECUTE ON FUNCTION public.create_sale(uuid, jsonb, numeric, public.payment_mode, numeric, uuid, text, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.create_purchase(uuid, jsonb, numeric, uuid, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.collect_due(uuid, uuid, numeric, public.payment_mode) TO authenticated;