CREATE OR REPLACE FUNCTION public.increment_usage(p_user_id UUID, p_date DATE)
RETURNS void LANGUAGE sql AS $$
  INSERT INTO public.usage_daily (user_id, date, count)
  VALUES (p_user_id, p_date, 1)
  ON CONFLICT (user_id, date)
  DO UPDATE SET count = usage_daily.count + 1;
$$;
