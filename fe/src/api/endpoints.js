import { api, request } from './client';

// Một hàm cho mỗi endpoint của backend (qua Gateway). Không chứa logic nghiệp vụ; tên trường giữ nguyên theo backend.
const AUTH = '/api/v1/auth';
const APPT = '/api/v1/appointments';
const CLIN = '/api/v1/clinical';
const VISITS = `${CLIN}/pet-visits`;
const PHARM = '/api/v1/pharmacy';
const BILL = '/api/v1/billing';

export const authApi = {
  login: (username, password) => request(`${AUTH}/login`, { method: 'POST', body: { username, password }, auth: false }),
  register: (body) => request(`${AUTH}/register`, { method: 'POST', body, auth: false }),
  logout: (refreshToken) => request(`${AUTH}/logout`, { method: 'POST', body: { refreshToken }, auth: false }),
  me: () => api.get(`${AUTH}/me`),
  updateMe: (body) => api.put(`${AUTH}/me`, body),
  changePassword: (body) => api.post(`${AUTH}/change-password`, body),
};

export const usersApi = {
  list: (query) => api.get(`${AUTH}/users`, query),
  doctors: () => api.get(`${AUTH}/users/doctors`),
  get: (id) => api.get(`${AUTH}/users/${id}`),
  create: (body) => api.post(`${AUTH}/users`, body),
  update: (id, body) => api.put(`${AUTH}/users/${id}`, body),
  changeStatus: (id, status) => api.post(`${AUTH}/users/${id}/status`, { status }),
  changeRole: (id, roleCode) => api.post(`${AUTH}/users/${id}/role`, { roleCode }),
  resetPassword: (id, newPassword) => api.post(`${AUTH}/users/${id}/reset-password`, { newPassword }),
};

export const catalogApi = {
  species: () => api.get('/api/v1/species'),
  createSpecies: (body) => api.post('/api/v1/species', body),
  updateSpecies: (id, body) => api.put(`/api/v1/species/${id}`, body),
  services: (includeInactive = false) => api.get(`${CLIN}/services`, { includeInactive }),
  createService: (body) => api.post(`${CLIN}/services`, body),
  updateService: (id, body) => api.put(`${CLIN}/services/${id}`, body),
  labItems: () => api.get(`${CLIN}/lab-test-items`),
  createLabItem: (body) => api.post(`${CLIN}/lab-test-items`, body),
  updateLabItem: (id, body) => api.put(`${CLIN}/lab-test-items/${id}`, body),
  saveRange: (itemId, speciesId, body) => api.put(`${CLIN}/lab-test-items/${itemId}/ranges/${speciesId}`, body),
  serviceLabItems: (serviceId) => api.get(`${CLIN}/services/${serviceId}/lab-test-items`),
  setServiceLabItems: (serviceId, labTestItemIds) => api.put(`${CLIN}/services/${serviceId}/lab-test-items`, { labTestItemIds }),
};

export const petsApi = {
  list: (query) => api.get('/api/v1/pets', query),
  get: (id) => api.get(`/api/v1/pets/${id}`),
  create: (body) => api.post('/api/v1/pets', body),
  update: (id, body) => api.put(`/api/v1/pets/${id}`, body),
  visits: (id) => api.get(`/api/v1/pets/${id}/visits`),
  medicalHistory: (id, query) => api.get(`/api/v1/pets/${id}/medical-history`, query),
};

export const appointmentsApi = {
  // Công khai (Gateway cho qua không cần token) nên Portal xem được khi chưa đăng nhập
  slots: (date) => api.get(`${APPT}/slots`, { date }, { auth: false }),
  list: (query) => api.get(APPT, query),
  get: (id) => api.get(`${APPT}/${id}`),
  history: (id) => api.get(`${APPT}/${id}/history`),
  create: (body) => api.post(APPT, body),
  confirm: (id) => api.post(`${APPT}/${id}/confirm`),
  cancel: (id, reason) => api.post(`${APPT}/${id}/cancel`, { reason }),
  reschedule: (id, body) => api.post(`${APPT}/${id}/reschedule`, body),
  noShow: (id) => api.post(`${APPT}/${id}/no-show`),
  report: (query) => api.get(`${APPT}/reports/summary`, query),
};

export const visitsApi = {
  checkIn: (body) => api.post(`${VISITS}/check-in`, body),
  // Bảng điều phối: { unassigned, doctors: [{ doctorId, fullName, roomNumber, status, waitingCount, visits }], suggestedDoctorId }
  queue: () => api.get(`${VISITS}/queue`),
  myQueue: () => api.get(`${VISITS}/my-queue`),
  list: (query) => api.get(VISITS, query),
  withDebt: () => api.get(`${VISITS}/with-debt`),
  get: (id) => api.get(`${VISITS}/${id}`),
  history: (id) => api.get(`${VISITS}/${id}/history`),
  assignDoctor: (id, doctorId) => api.post(`${VISITS}/${id}/assign-doctor`, { doctorId }),
  unassignDoctor: (id) => api.post(`${VISITS}/${id}/unassign-doctor`),
  startExam: (id, body) => api.post(`${VISITS}/${id}/start-exam`, body),
  clinicalInfo: (id, body) => api.put(`${VISITS}/${id}/clinical-info`, body),
  paraclinicalOrders: (id, serviceIds, notes) => api.post(`${VISITS}/${id}/paraclinical-orders`, { serviceIds, notes: notes || null }),
  inRoomServices: (id, services) => api.post(`${VISITS}/${id}/in-room-services`, { services }),
  startPhase2: (id) => api.post(`${VISITS}/${id}/start-phase2`),
  closeVisit: (id, body) => api.post(`${VISITS}/${id}/close-visit`, body),
  cancelExam: (id, reason) => api.post(`${VISITS}/${id}/cancel-exam`, { reason }),
  abandon: (id) => api.post(`${VISITS}/${id}/abandon`),
  cancel: (id, reason) => api.post(`${VISITS}/${id}/cancel`, { reason }),
  reopen: (id, reason) => api.post(`${VISITS}/${id}/reopen`, { reason }),
  doctorsStatus: () => api.get(`${CLIN}/doctors/status`),
  myVisits: () => api.get(`${CLIN}/doctors/me/visits`),
  // Hóa đơn dịch vụ (mỗi dịch vụ một hóa đơn, thu một phần được)
  serviceInvoices: (id) => api.get(`${VISITS}/${id}/service-invoices`),
  confirmServicePayment: (id, invoiceIds) => api.post(`${VISITS}/${id}/service-invoices/confirm-payment`, { invoiceIds }),
  discountServiceInvoice: (invoiceId, discountAmount) => api.post(`${CLIN}/service-invoices/${invoiceId}/discount`, { discountAmount }),
  // Màn hình thu ngân 3 mục: EXAM_FEE (chờ nộp phí khám), PARACLINIC (chờ nộp tiền XN / CĐHA), FINAL (đã chốt ca)
  cashierPending: (section) => api.get(`${CLIN}/cashier/pending`, { section }),
};

/** Phiếu xếp hàng (SM-07): hàng đợi Bác sĩ / Lab / CĐHA. "Gọi" chỉ báo khách, không đổi thứ tự hay trạng thái. */
export const queueTicketsApi = {
  callNext: (queueType) => api.post(`${CLIN}/queue-tickets/call-next?queueType=${queueType}`),
  call: (ticketId) => api.post(`${CLIN}/queue-tickets/${ticketId}/call`),
  start: (ticketId) => api.post(`${CLIN}/queue-tickets/${ticketId}/start`),
};

export const paraclinicApi = {
  labQueue: () => api.get(`${CLIN}/lab-queue`),
  imagingQueue: () => api.get(`${CLIN}/imaging-queue`),
  sampleCollected: (detailId) => api.post(`${CLIN}/service-details/${detailId}/sample-collected`),
  perform: (detailId) => api.post(`${CLIN}/service-details/${detailId}/perform`),
  // reasonType: CUSTOMER (khách tự hủy, không hoàn tiền) | CLINIC (phòng khám không làm được, hoàn tiền nếu đã thu)
  cancel: (detailId, reason, reasonType) => api.post(`${CLIN}/service-details/${detailId}/cancel`, { reason, reasonType: reasonType || null }),
  labForm: (detailId) => api.get(`${CLIN}/service-details/${detailId}/lab-form`),
  saveLabResults: (detailId, results) => api.post(`${CLIN}/lab-results/${detailId}`, { results }),
  saveImagingResult: (detailId, { description, conclusion, files }) => {
    const form = new FormData();
    form.append('description', description);
    form.append('conclusion', conclusion || '');
    files.forEach((file) => form.append('files', file));
    return api.upload(`${CLIN}/imaging-results/${detailId}`, form);
  },
  attachment: (attachmentId) => api.blob(`${CLIN}/imaging-attachments/${attachmentId}/file`),
};

export const pharmacyApi = {
  medicines: (query) => api.get(`${PHARM}/medicines`, query),
  medicine: (id) => api.get(`${PHARM}/medicines/${id}`),
  createMedicine: (body) => api.post(`${PHARM}/medicines`, body),
  updateMedicine: (id, body) => api.put(`${PHARM}/medicines/${id}`, body),
  transactions: (id, query) => api.get(`${PHARM}/medicines/${id}/transactions`, query),
  importStock: (medicineId, body) => api.post(`${PHARM}/inventory/import`, { medicineId, ...body }),
  adjustStock: (medicineId, body) => api.post(`${PHARM}/inventory/adjust`, { medicineId, ...body }),
  // Đơn thuốc v3.0: không giá, không trạng thái; kê vượt tồn chỉ cảnh báo (stockWarnings)
  prescriptions: (query) => api.get(`${PHARM}/prescriptions`, query),
  prescription: (id) => api.get(`${PHARM}/prescriptions/${id}`),
  prescriptionByVisit: (visitId) => api.get(`${PHARM}/prescriptions/by-visit/${visitId}`),
  printPrescription: (id) => api.get(`${PHARM}/prescriptions/${id}/print`),
  createPrescription: (body) => api.post(`${PHARM}/prescriptions`, body),
  updatePrescription: (id, body) => api.put(`${PHARM}/prescriptions/${id}`, body),
  // Hóa đơn thuốc (chỉ khi khách chọn mua tại phòng khám)
  createMedicineInvoice: (prescriptionId, body) => api.post(`${PHARM}/prescriptions/${prescriptionId}/medicine-invoices`, body),
};

export const billingApi = {
  medicineInvoice: (id) => api.get(`${BILL}/medicine-invoices/${id}`),
  updateMedicineInvoiceItems: (id, body) => api.put(`${BILL}/medicine-invoices/${id}/items`, body),
  cancelMedicineInvoice: (id) => api.post(`${BILL}/medicine-invoices/${id}/cancel`),
  confirmMedicinePayment: (id) => api.post(`${BILL}/medicine-invoices/${id}/confirm-payment`),
  // Doanh thu THUỐC; doanh thu dịch vụ + công nợ ở reportsApi.serviceRevenue (Admin cộng hai nguồn)
  medicineRevenue: (query) => api.get(`${BILL}/reports/revenue`, query),
};

export const reportsApi = {
  operations: (query) => api.get(`${CLIN}/reports/operations`, query),
  serviceRevenue: (query) => api.get(`${CLIN}/reports/revenue`, query),
};

export const notificationsApi = {
  list: (limit = 50) => api.get('/api/v1/notifications', { limit }),
  markRead: (id) => api.post(`/api/v1/notifications/${id}/read`),
};
