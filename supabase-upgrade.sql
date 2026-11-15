-- ============================================================
-- ترقية تطبيق "ديون المذاخر" — مشروع Supabase: nykqikmznmwnyiweerut
-- سلة محذوفات + سجل تدقيق (إضافات جديدة فقط — لا يعدّل أي جدول حالي)
-- طريقة التنفيذ: Supabase Dashboard → SQL Editor → الصق الملف كاملاً → Run
-- آمن للتنفيذ مرة واحدة، وإعادة تنفيذه لا تضر (IF NOT EXISTS / DROP POLICY IF EXISTS)
-- ============================================================

-- 1) جدول سلة المحذوفات: تُحفظ فيه نسخة من أي فاتورة قبل حذفها حتى يمكن استرجاعها
create table if not exists public.trash_items (
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz not null default now(),
  user_id uuid,
  entity text not null,          -- 'invoice'
  payload jsonb not null         -- نسخة كاملة من الفاتورة المحذوفة
);

-- 2) جدول سجل التدقيق: شنو صار ومتى (حفظ/تسديد/حذف/استرجاع...)
create table if not exists public.audit_log (
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz not null default now(),
  user_id uuid,
  action text not null,
  entity text,
  entity_id text,
  details jsonb
);

-- 3) تفعيل أمان الصفوف (RLS) على الجدولين الجديدين
alter table public.trash_items enable row level security;
alter table public.audit_log enable row level security;

-- 4) الصلاحيات: كل مستخدم يشوف ويعدّل بياناته فقط
drop policy if exists trash_select on public.trash_items;
create policy trash_select on public.trash_items for select to authenticated
  using (user_id = auth.uid());

drop policy if exists trash_insert on public.trash_items;
create policy trash_insert on public.trash_items for insert to authenticated
  with check (user_id = auth.uid());

drop policy if exists trash_delete on public.trash_items;
create policy trash_delete on public.trash_items for delete to authenticated
  using (user_id = auth.uid());

drop policy if exists audit_select on public.audit_log;
create policy audit_select on public.audit_log for select to authenticated
  using (user_id = auth.uid());

drop policy if exists audit_insert on public.audit_log;
create policy audit_insert on public.audit_log for insert to authenticated
  with check (user_id = auth.uid());
-- ملاحظة: لا توجد صلاحية تعديل/حذف على audit_log عمداً، حتى يبقى السجل غير قابل للعبث.

-- ============================================================
-- فحص اختياري (شغّل كل سطر وحده واقرأ النتيجة — لا يغيّر شيئاً):
--   select tablename, policyname, cmd, roles from pg_policies where schemaname = 'public' order by tablename;
--   select relname, relrowsecurity from pg_class where relname in ('pharm_invoices','pharm_suppliers');
--
-- تنبيه مهم: جدول pharm_invoices حالياً لا يحتوي عمود user_id، والتطبيق
-- يقرأ كل الصفوف. إذا كان حساب واحد فقط يستخدم التطبيق فالوضع مقبول عملياً
-- بشرط أن تكون سياسات RLS على الجدول تسمح للمستخدمين المسجلين فقط.
-- أما إذا أظهر الفحص أن relrowsecurity = false فهذا يعني أن أي شخص يملك
-- مفتاح الاتصال العام يقدر يقرأ كل الفواتير — عندها يجب تفعيل RLS وإضافة
-- سياسة للمستخدمين المسجلين على الأقل:
--
--   alter table public.pharm_invoices enable row level security;
--   create policy invoices_auth on public.pharm_invoices for all to authenticated
--     using (true) with check (true);
--
-- ⚠️ لا تنفّذ الإصلاح إلا بعد مراجعته، وجرّب التطبيق مباشرة بعده.
-- خطوة مستقبلية أقوى (تحتاج تحديث كود التطبيق بنفس الوقت): إضافة عمود
-- user_id لجدول pharm_invoices وربط كل فاتورة بصاحبها.
-- ============================================================
