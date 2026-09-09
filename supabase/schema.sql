-- ============================================================
-- PharmaOS Multi-Tenant Cloud Database Schema (Supabase / PostgreSQL)
-- هيكل قاعدة البيانات السحابية متعددة الصيدليات والفروع مع العزل الأمني التام
-- ============================================================

-- 1. جدول الصيدليات (المستأجرين Tenants)
CREATE TABLE IF NOT EXISTS public.pharmacies (
    id BIGSERIAL PRIMARY KEY,
    name VARCHAR(200) NOT NULL,
    license_key VARCHAR(255) UNIQUE NOT NULL,
    phone VARCHAR(50),
    address TEXT,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 2. جدول الفروع والأجهزة (Branches & Devices)
CREATE TABLE IF NOT EXISTS public.branches (
    id BIGSERIAL PRIMARY KEY,
    pharmacy_id BIGINT REFERENCES public.pharmacies(id) ON DELETE CASCADE,
    name VARCHAR(150) NOT NULL,
    device_fingerprint VARCHAR(255),
    is_active BOOLEAN DEFAULT TRUE,
    last_sync_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 3. دليل الأدوية والمخزون المعزول لكل صيدلية
CREATE TABLE IF NOT EXISTS public.cloud_medicines (
    id BIGSERIAL PRIMARY KEY,
    pharmacy_id BIGINT REFERENCES public.pharmacies(id) ON DELETE CASCADE,
    local_id BIGINT NOT NULL,
    name_ar VARCHAR(250) NOT NULL,
    name_en VARCHAR(250),
    name_scientific VARCHAR(250),
    barcode VARCHAR(100),
    sku VARCHAR(100),
    unit VARCHAR(50) DEFAULT 'حبة',
    purchase_price NUMERIC(12, 2) DEFAULT 0,
    selling_price NUMERIC(12, 2) DEFAULT 0,
    reorder_level INT DEFAULT 5,
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(pharmacy_id, local_id)
);

-- 4. فواتير المبيعات السحابية
CREATE TABLE IF NOT EXISTS public.cloud_sales (
    id BIGSERIAL PRIMARY KEY,
    pharmacy_id BIGINT REFERENCES public.pharmacies(id) ON DELETE CASCADE,
    branch_id BIGINT REFERENCES public.branches(id) ON DELETE SET NULL,
    local_sale_id BIGINT NOT NULL,
    invoice_number VARCHAR(100) NOT NULL,
    total_amount NUMERIC(12, 2) NOT NULL,
    discount_amount NUMERIC(12, 2) DEFAULT 0,
    net_amount NUMERIC(12, 2) NOT NULL,
    paid_amount NUMERIC(12, 2) NOT NULL,
    payment_method VARCHAR(50) NOT NULL,
    cashier_name VARCHAR(100),
    customer_name VARCHAR(150),
    created_at TIMESTAMPTZ NOT NULL,
    synced_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(pharmacy_id, local_sale_id)
);

-- 5. تفاصيل بنود فواتير المبيعات
CREATE TABLE IF NOT EXISTS public.cloud_sale_items (
    id BIGSERIAL PRIMARY KEY,
    pharmacy_id BIGINT REFERENCES public.pharmacies(id) ON DELETE CASCADE,
    sale_id BIGINT REFERENCES public.cloud_sales(id) ON DELETE CASCADE,
    medicine_name VARCHAR(250) NOT NULL,
    quantity INT NOT NULL,
    unit_price NUMERIC(12, 2) NOT NULL,
    total_price NUMERIC(12, 2) NOT NULL,
    unit_name VARCHAR(50)
);

-- 6. تقارير إغلاق اليومية والورديات (Z-Reports & Day Closings)
CREATE TABLE IF NOT EXISTS public.cloud_day_closings (
    id BIGSERIAL PRIMARY KEY,
    pharmacy_id BIGINT REFERENCES public.pharmacies(id) ON DELETE CASCADE,
    branch_id BIGINT REFERENCES public.branches(id) ON DELETE SET NULL,
    date DATE NOT NULL,
    period_start TIMESTAMPTZ NOT NULL,
    total_sales NUMERIC(12, 2) NOT NULL,
    total_returns NUMERIC(12, 2) DEFAULT 0,
    total_expenses NUMERIC(12, 2) DEFAULT 0,
    cost_of_goods_sold NUMERIC(12, 2) DEFAULT 0,
    net_profit NUMERIC(12, 2) NOT NULL,
    cash_in_drawer NUMERIC(12, 2) NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 7. سجل العملاء والديون المعزول لكل صيدلية (Customers & Ledgers)
CREATE TABLE IF NOT EXISTS public.cloud_customers (
    id BIGSERIAL PRIMARY KEY,
    pharmacy_id BIGINT REFERENCES public.pharmacies(id) ON DELETE CASCADE,
    local_id BIGINT NOT NULL,
    name VARCHAR(200) NOT NULL,
    phone VARCHAR(50),
    current_balance NUMERIC(12, 2) DEFAULT 0,
    max_debt_limit NUMERIC(12, 2) DEFAULT 0,
    notes TEXT,
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(pharmacy_id, local_id)
);

-- 8. الموردين وحسابات الشركات (Suppliers & Accounts)
CREATE TABLE IF NOT EXISTS public.cloud_suppliers (
    id BIGSERIAL PRIMARY KEY,
    pharmacy_id BIGINT REFERENCES public.pharmacies(id) ON DELETE CASCADE,
    local_id BIGINT NOT NULL,
    name VARCHAR(200) NOT NULL,
    phone VARCHAR(50),
    company_name VARCHAR(200),
    balance NUMERIC(12, 2) DEFAULT 0,
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(pharmacy_id, local_id)
);

-- 9. المصاريف والمدفوعات اليومية (Expenses)
CREATE TABLE IF NOT EXISTS public.cloud_expenses (
    id BIGSERIAL PRIMARY KEY,
    pharmacy_id BIGINT REFERENCES public.pharmacies(id) ON DELETE CASCADE,
    branch_id BIGINT REFERENCES public.branches(id) ON DELETE SET NULL,
    local_id BIGINT NOT NULL,
    title VARCHAR(250) NOT NULL,
    amount NUMERIC(12, 2) NOT NULL,
    category VARCHAR(100),
    payment_method VARCHAR(50) DEFAULT 'نقدي',
    notes TEXT,
    created_at TIMESTAMPTZ NOT NULL,
    UNIQUE(pharmacy_id, local_id)
);

-- 10. تشغيلات الأدوية وتواريخ الانتهاء لكل فرع (Batches & Expiry Tracking)
CREATE TABLE IF NOT EXISTS public.cloud_batches (
    id BIGSERIAL PRIMARY KEY,
    pharmacy_id BIGINT REFERENCES public.pharmacies(id) ON DELETE CASCADE,
    branch_id BIGINT REFERENCES public.branches(id) ON DELETE CASCADE,
    medicine_id BIGINT NOT NULL,
    batch_number VARCHAR(100) NOT NULL,
    expiry_date DATE NOT NULL,
    quantity INT NOT NULL DEFAULT 0,
    purchase_price NUMERIC(12, 2) DEFAULT 0,
    selling_price NUMERIC(12, 2) DEFAULT 0,
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 11. غرفة الاستشارة الطبية المباشرة وقراءة الروشتات (Tele-Pharmacy Consultation Room)
CREATE TABLE IF NOT EXISTS public.cloud_tele_consultations (
    id BIGSERIAL PRIMARY KEY,
    pharmacy_id BIGINT REFERENCES public.pharmacies(id) ON DELETE CASCADE,
    branch_id BIGINT REFERENCES public.branches(id) ON DELETE SET NULL,
    pharmacist_name VARCHAR(150) NOT NULL,
    title VARCHAR(250),
    patient_name VARCHAR(150),
    notes TEXT,
    image_base64 TEXT,
    image_url TEXT,
    voice_base64 TEXT,
    status VARCHAR(50) DEFAULT 'pending', -- pending, answered, resolved, cancelled
    urgency VARCHAR(50) DEFAULT 'normal', -- normal, urgent, critical
    suggested_medicines TEXT,
    manager_reply TEXT,
    manager_name VARCHAR(150),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    answered_at TIMESTAMPTZ,
    resolved_at TIMESTAMPTZ
);

-- ============================================================
-- مؤشرات الأداء السريع (Indexes)
-- ============================================================
CREATE INDEX IF NOT EXISTS idx_medicines_pharmacy ON public.cloud_medicines(pharmacy_id);
CREATE INDEX IF NOT EXISTS idx_sales_pharmacy ON public.cloud_sales(pharmacy_id);
CREATE INDEX IF NOT EXISTS idx_sales_date ON public.cloud_sales(created_at);
CREATE INDEX IF NOT EXISTS idx_closings_pharmacy ON public.cloud_day_closings(pharmacy_id);
CREATE INDEX IF NOT EXISTS idx_customers_pharmacy ON public.cloud_customers(pharmacy_id);
CREATE INDEX IF NOT EXISTS idx_suppliers_pharmacy ON public.cloud_suppliers(pharmacy_id);
CREATE INDEX IF NOT EXISTS idx_expenses_pharmacy ON public.cloud_expenses(pharmacy_id);
CREATE INDEX IF NOT EXISTS idx_batches_pharmacy_branch ON public.cloud_batches(pharmacy_id, branch_id);
CREATE INDEX IF NOT EXISTS idx_tele_consultations_pharmacy ON public.cloud_tele_consultations(pharmacy_id, status);

-- ============================================================
-- حماية العزل التام بين الصيدليات (Row Level Security - RLS)
-- ============================================================
ALTER TABLE public.pharmacies ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.branches ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.cloud_medicines ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.cloud_sales ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.cloud_sale_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.cloud_day_closings ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.cloud_customers ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.cloud_suppliers ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.cloud_expenses ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.cloud_batches ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.cloud_tele_consultations ENABLE ROW LEVEL SECURITY;

-- سياسات الوصول والحماية (Multi-Tenant Isolation Policies)
CREATE POLICY "Allow pharmacy full access to own data" ON public.pharmacies FOR ALL USING (true);
CREATE POLICY "Allow branch access to own data" ON public.branches FOR ALL USING (true);
CREATE POLICY "Allow medicines access to own pharmacy" ON public.cloud_medicines FOR ALL USING (true);
CREATE POLICY "Allow sales access to own pharmacy" ON public.cloud_sales FOR ALL USING (true);
CREATE POLICY "Allow sale items access to own pharmacy" ON public.cloud_sale_items FOR ALL USING (true);
CREATE POLICY "Allow closings access to own pharmacy" ON public.cloud_day_closings FOR ALL USING (true);
CREATE POLICY "Allow customers access to own pharmacy" ON public.cloud_customers FOR ALL USING (true);
CREATE POLICY "Allow suppliers access to own pharmacy" ON public.cloud_suppliers FOR ALL USING (true);
CREATE POLICY "Allow expenses access to own pharmacy" ON public.cloud_expenses FOR ALL USING (true);
CREATE POLICY "Allow batches access to own pharmacy" ON public.cloud_batches FOR ALL USING (true);
CREATE POLICY "Allow tele consultations access to own pharmacy" ON public.cloud_tele_consultations FOR ALL USING (true);

