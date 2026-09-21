document.addEventListener('DOMContentLoaded', () => {
    loadTenants();

    document.getElementById('newPharmacyForm').addEventListener('submit', async (e) => {
        e.preventDefault();
        await registerNewPharmacy();
    });
});

async function loadTenants() {
    const statusInd = document.getElementById('statusIndicator');
    statusInd.textContent = 'جاري التحميل...';
    statusInd.className = 'px-3 py-1 bg-yellow-500 rounded-full text-sm text-white';

    const { data, error } = await window.supabaseClient
        .from('pharmacies')
        .select('*')
        .order('created_at', { ascending: false });

    if (error) {
        console.error('Error fetching tenants:', error);
        statusInd.textContent = 'خطأ في الاتصال';
        statusInd.className = 'px-3 py-1 bg-red-500 rounded-full text-sm text-white';
        Swal.fire('خطأ', 'فشل تحميل بيانات الصيدليات: ' + error.message, 'error');
        return;
    }

    statusInd.textContent = 'متصل';
    statusInd.className = 'px-3 py-1 bg-green-500 rounded-full text-sm text-white';

    renderTable(data);
    updateStats(data);
}

function renderTable(data) {
    const tbody = document.getElementById('tenantsTableBody');
    tbody.innerHTML = '';

    if (data.length === 0) {
        tbody.innerHTML = '<tr><td colspan="5" class="text-center py-4 text-gray-500">لا يوجد صيدليات مسجلة بعد.</td></tr>';
        return;
    }

    data.forEach(tenant => {
        const tr = document.createElement('tr');
        
        const statusBadge = tenant.is_active 
            ? '<span class="px-2 inline-flex text-xs leading-5 font-semibold rounded-full bg-green-100 text-green-800">نشط</span>'
            : (tenant.paused_by_admin 
                ? '<span class="px-2 inline-flex text-xs leading-5 font-semibold rounded-full bg-yellow-100 text-yellow-800">معلق</span>'
                : '<span class="px-2 inline-flex text-xs leading-5 font-semibold rounded-full bg-red-100 text-red-800">متوقف</span>');

        const licenseTypeAr = tenant.license_type === 'single' ? 'فردية' : 'لها فروع';
        
        let branchesButton = '';
        if (tenant.license_type === 'multi') {
            branchesButton = `<button onclick="openBranchesModal('${tenant.id}', '${tenant.name}')" class="text-sm px-3 py-1 rounded shadow bg-blue-500 text-white hover:bg-blue-600 mr-2">الفروع</button>`;
        }

        tr.innerHTML = `
            <td class="px-6 py-4 whitespace-nowrap font-bold text-right">${tenant.name}</td>
            <td class="px-6 py-4 whitespace-nowrap font-mono text-sm bg-gray-50 text-right">${tenant.license_key}</td>
            <td class="px-6 py-4 whitespace-nowrap text-right">${statusBadge}</td>
            <td class="px-6 py-4 whitespace-nowrap text-right">${licenseTypeAr}</td>
            <td class="px-6 py-4 whitespace-nowrap text-center">
                <button onclick="toggleStatus('${tenant.id}', ${tenant.is_active})" class="text-sm px-3 py-1 rounded shadow ${tenant.is_active ? 'bg-yellow-500 text-white hover:bg-yellow-600' : 'bg-green-500 text-white hover:bg-green-600'}">
                    ${tenant.is_active ? 'إيقاف' : 'تفعيل'}
                </button>
                ${branchesButton}
            </td>
        `;
        tbody.appendChild(tr);
    });
}

function updateStats(data) {
    document.getElementById('totalPharmacies').textContent = data.length;
    document.getElementById('activePharmacies').textContent = data.filter(d => d.is_active).length;
    document.getElementById('pausedPharmacies').textContent = data.filter(d => !d.is_active).length;
}

function generateLicenseKey() {
    // Generate a random license key in format: PHARMA-XXXX-XXXX-XXXX
    const randChars = () => Math.random().toString(36).substring(2, 6).toUpperCase();
    return `PHARMA-${randChars()}-${randChars()}-${randChars()}`;
}

async function registerNewPharmacy() {
    const name = document.getElementById('pharmacyName').value.trim();
    const licenseType = document.getElementById('licenseType').value;
    const subType = document.getElementById('subType').value;
    const deviceFingerprint = document.getElementById('deviceFingerprint').value.trim();

    if (!name) {
        Swal.fire('تنبيه', 'يرجى إدخال اسم الصيدلية', 'warning');
        return;
    }

    const licenseKey = generateLicenseKey();
    
    // حساب مدة الصلاحية
    let validUntil = new Date();
    if (subType === 'monthly') validUntil.setMonth(validUntil.getMonth() + 1);
    else if (subType === 'yearly') validUntil.setFullYear(validUntil.getFullYear() + 1);
    else if (subType === 'lifetime') validUntil.setFullYear(validUntil.getFullYear() + 100);

    const { data, error } = await window.supabaseClient
        .from('pharmacies')
        .insert([
            {
                name: name,
                license_key: licenseKey,
                is_active: true,
                license_type: licenseType,
                subscription_type: subType,
                subscription_end: validUntil.toISOString(),
                device_fingerprint: deviceFingerprint || null
            }
        ])
        .select();

    if (error) {
        Swal.fire('خطأ', 'فشل تسجيل الصيدلية: ' + error.message, 'error');
    } else {
        Swal.fire('تم بنجاح', `تم إصدار الرخصة بنجاح\nالكود: ${licenseKey}`, 'success');
        document.getElementById('newPharmacyForm').reset();
        loadTenants();
    }
}

async function toggleStatus(id, isActive) {
    const newStatus = !isActive;
    const actionText = newStatus ? 'تفعيل' : 'إيقاف';
    
    const result = await Swal.fire({
        title: `تأكيد ال${actionText}`,
        text: `هل أنت متأكد من ${actionText} هذه الصيدلية؟`,
        icon: 'warning',
        showCancelButton: true,
        confirmButtonText: 'نعم',
        cancelButtonText: 'إلغاء'
    });

    if (result.isConfirmed) {
        const { error } = await window.supabaseClient
            .from('pharmacies')
            .update({ is_active: newStatus, paused_by_admin: !newStatus })
            .eq('id', id);

        if (error) {
            Swal.fire('خطأ', 'حدث خطأ أثناء التحديث: ' + error.message, 'error');
        } else {
            // سجل العملية في جدول التدقيق (Admin Audit)
            await window.supabaseClient.from('admin_audit_log').insert([
                {
                    action: newStatus ? 'RESUME_TENANT' : 'PAUSE_TENANT',
                    target_pharmacy_id: id,
                    details: JSON.stringify({ previous_is_active: isActive, new_is_active: newStatus })
                }
            ]);

            Swal.fire('تم بنجاح', `تم ${actionText} الصيدلية بنجاح`, 'success');
            loadTenants();
        }
    }
}

// ----------------------------------------------------
// Branches Management
// ----------------------------------------------------

function closeBranchesModal() {
    document.getElementById('branchesModal').classList.add('hidden');
}

async function openBranchesModal(pharmacyId, pharmacyName) {
    document.getElementById('branchesModalTitle').textContent = `فروع الصيدلية: ${pharmacyName}`;
    document.getElementById('branchesModal').classList.remove('hidden');
    
    await loadBranches(pharmacyId);
}

async function loadBranches(pharmacyId) {
    const tbody = document.getElementById('branchesTableBody');
    tbody.innerHTML = '<tr><td colspan="4" class="text-center py-4 text-gray-500">جاري التحميل...</td></tr>';

    const { data, error } = await window.supabaseClient
        .from('branches')
        .select('*')
        .eq('pharmacy_id', pharmacyId)
        .order('created_at', { ascending: true });

    if (error) {
        tbody.innerHTML = `<tr><td colspan="4" class="text-center py-4 text-red-500">خطأ في التحميل: ${error.message}</td></tr>`;
        return;
    }

    if (!data || data.length === 0) {
        tbody.innerHTML = '<tr><td colspan="4" class="text-center py-4 text-gray-500">لا يوجد فروع مسجلة لهذه الصيدلية حتى الآن.</td></tr>';
        return;
    }

    tbody.innerHTML = '';
    data.forEach(branch => {
        const tr = document.createElement('tr');
        
        const statusBadge = branch.is_active 
            ? '<span class="px-2 inline-flex text-xs leading-5 font-semibold rounded-full bg-green-100 text-green-800">نشط</span>'
            : '<span class="px-2 inline-flex text-xs leading-5 font-semibold rounded-full bg-red-100 text-red-800">متوقف</span>';

        tr.innerHTML = `
            <td class="px-4 py-3 whitespace-nowrap font-bold text-right">${branch.name}</td>
            <td class="px-4 py-3 whitespace-nowrap font-mono text-sm bg-gray-50 text-right">${branch.branch_activation_key || '-'}</td>
            <td class="px-4 py-3 whitespace-nowrap text-right">${statusBadge}</td>
            <td class="px-4 py-3 whitespace-nowrap text-center">
                <button onclick="toggleBranchStatus('${branch.id}', ${branch.is_active}, '${pharmacyId}')" class="text-sm px-3 py-1 rounded shadow ${branch.is_active ? 'bg-yellow-500 text-white hover:bg-yellow-600' : 'bg-green-500 text-white hover:bg-green-600'}">
                    ${branch.is_active ? 'إيقاف' : 'تفعيل'}
                </button>
            </td>
        `;
        tbody.appendChild(tr);
    });
}

async function toggleBranchStatus(branchId, isActive, pharmacyId) {
    const newStatus = !isActive;
    const actionText = newStatus ? 'تفعيل' : 'إيقاف';
    
    const { error } = await window.supabaseClient
        .from('branches')
        .update({ is_active: newStatus })
        .eq('id', branchId);

    if (error) {
        Swal.fire('خطأ', 'حدث خطأ أثناء التحديث: ' + error.message, 'error');
    } else {
        await loadBranches(pharmacyId); // Refresh branches list
    }
}

