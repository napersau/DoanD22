import { useState } from 'react';
import StaffLayout from '../../layouts/StaffLayout';
import { AsyncView, Button, Field, Input, PageHead, Panel, Select, Stats, Table, Tabs } from '../../components/ui';
import { appointmentsApi, billingApi, reportsApi } from '../../api/endpoints';
import useAsync from '../../hooks/useAsync';
import { formatDate, formatMoney, formatNumber, todayIso } from '../../lib/format';
import { APPOINTMENT_STATUS, BOOKING_CHANNEL, PAYMENT_STATUS, SERVICE_CATEGORY, VISIT_STATUS } from '../../lib/labels';

const percent = (value) => `${formatNumber((value || 0) * 100, 1)}%`;
const MAX_DAYS = 366;

function Bars({ rows, label, value, format }) {
  const max = Math.max(...rows.map((row) => Number(row[value])), 1);
  return <div className="ui-stack" style={{ gap: 6 }} role="img" aria-label="Biểu đồ cột">
    {rows.map((row) => <div key={row[label]} style={{ display: 'grid', gridTemplateColumns: '110px 1fr 120px', gap: 10, alignItems: 'center', fontSize: 12 }}>
      <span className="ui-muted">{row[label]}</span>
      <div style={{ background: 'var(--ui-raised)', borderRadius: 6, height: 14 }}><div style={{ width: `${(Number(row[value]) / max) * 100}%`, height: '100%', borderRadius: 6, background: 'var(--ui-brand)' }} /></div>
      <strong style={{ textAlign: 'right', color: 'var(--ui-text)' }}>{format(row[value])}</strong>
    </div>)}
  </div>;
}

/** Doanh thu v3.0 có HAI nguồn ở hai service: dịch vụ + công nợ (clinical) và thuốc (billing-pharmacy); trang này cộng hai nguồn. */
function Revenue({ range, groupBy }) {
  const report = useAsync(async () => {
    const [service, medicine] = await Promise.all([reportsApi.serviceRevenue(range), billingApi.medicineRevenue({ ...range, groupBy })]);
    return { service, medicine };
  }, [range.fromDate, range.toDate, groupBy]);
  return <AsyncView state={report}>{({ service, medicine }) => {
    const serviceTotal = Number(service.totalPaid);
    const medicineTotal = Number(medicine.totals.payableAmount);
    return <>
      <Stats items={[['Doanh thu thực thu', formatMoney(serviceTotal + medicineTotal), `${service.paidInvoiceCount + medicine.totals.invoiceCount} hóa đơn đã thanh toán`, 'green'],
        ['Dịch vụ', formatMoney(serviceTotal), `${service.paidInvoiceCount} hóa đơn dịch vụ`], ['Thuốc', formatMoney(medicineTotal), `${medicine.totals.invoiceCount} hóa đơn thuốc`],
        ['Công nợ hiện tại', formatMoney(service.debt.amount), `${service.debt.visitCount} ca · ${service.debt.invoiceCount} hóa đơn`, service.debt.invoiceCount ? 'amber' : '']]} />
      <div className="ui-cols">
        <Panel title="Doanh thu dịch vụ theo nhóm" subtitle="Hóa đơn dịch vụ đã thu trong kỳ (giờ Việt Nam)." flush>
          <Table caption="Doanh thu dịch vụ theo nhóm" rowKey="category" empty="Chưa có doanh thu dịch vụ trong kỳ." rows={service.byCategory} columns={[
            { title: 'Nhóm dịch vụ', render: (row) => SERVICE_CATEGORY[row.category] || row.category }, { title: 'HĐ', key: 'invoiceCount' },
            { title: 'Trước VAT', align: 'right', render: (row) => formatMoney(row.amountBeforeVat) }, { title: 'VAT', align: 'right', render: (row) => formatMoney(row.vatAmount) },
            { title: 'Giảm giá', align: 'right', render: (row) => formatMoney(row.discountAmount) }, { title: 'Thực thu', align: 'right', render: (row) => <strong>{formatMoney(row.payableAmount)}</strong> }]} />
        </Panel>
        <Panel title="Hóa đơn thuốc lập trong kỳ" subtitle="“Chờ thanh toán” là hóa đơn thuốc chưa thu." flush>
          <Table caption="Trạng thái hóa đơn thuốc" rowKey="status" rows={Object.entries(medicine.byStatus).map(([status, count]) => ({ status, count }))} columns={[
            { title: 'Trạng thái', render: (row) => PAYMENT_STATUS[row.status]?.label || row.status }, { title: 'Số hóa đơn', align: 'right', key: 'count' }]} />
        </Panel>
      </div>
      <Panel title="Doanh thu thuốc theo kỳ" subtitle="Theo ngày thu tiền, chỉ hóa đơn thuốc đã thanh toán (tiền thuốc đã gồm VAT, trừ giảm giá).">
        <Bars rows={medicine.periods} label="label" value="payableAmount" format={formatMoney} />
      </Panel>
      <Panel title="Chi tiết doanh thu thuốc theo kỳ" flush><Table caption="Doanh thu thuốc theo kỳ" rowKey="label" rows={medicine.periods} columns={[
        { title: 'Kỳ', key: 'label' }, { title: 'HĐ', key: 'invoiceCount' }, { title: 'Trước VAT', align: 'right', render: (row) => formatMoney(row.amountBeforeVat) },
        { title: 'VAT', align: 'right', render: (row) => formatMoney(row.vatAmount) }, { title: 'Giảm giá', align: 'right', render: (row) => formatMoney(row.discountAmount) },
        { title: 'Thực thu', align: 'right', render: (row) => <strong>{formatMoney(row.payableAmount)}</strong> }]} /></Panel>
    </>;
  }}</AsyncView>;
}

function Operations({ range }) {
  const report = useAsync(() => reportsApi.operations(range), [range.fromDate, range.toDate]);
  return <AsyncView state={report}>{(r) => <>
    <Stats items={[['Tổng số ca', r.totalVisits], ['Hoàn tất', r.completedVisits, undefined, 'green'], ['Đã hủy', r.cancelledVisits], ['Cấp cứu', r.emergencyVisits, undefined, r.emergencyVisits ? 'red' : ''], ['Ca thường', r.routineVisits], ['Ca có cận lâm sàng', r.paraclinicalVisits]]} />
    <div className="ui-cols">
      <Panel title="Ca khám theo trạng thái" flush><Table caption="Ca theo trạng thái" rowKey="status" rows={Object.entries(r.byStatus).map(([status, count]) => ({ status, count }))} columns={[{ title: 'Trạng thái', render: (row) => VISIT_STATUS[row.status]?.label || row.status }, { title: 'Số ca', align: 'right', key: 'count' }]} /></Panel>
      <Panel title="Khối lượng theo bác sĩ" flush><Table caption="Bác sĩ" rowKey="doctorId" rows={r.doctors} columns={[{ title: 'Bác sĩ', render: (row) => row.doctorName || `#${row.doctorId}` }, { title: 'Được giao', align: 'right', key: 'assignedVisits' }, { title: 'Hoàn tất', align: 'right', key: 'completedVisits' }]} empty="Chưa có ca nào được giao." /></Panel>
    </div>
  </>}</AsyncView>;
}

function Appointments({ range }) {
  const report = useAsync(() => appointmentsApi.report(range), [range.fromDate, range.toDate]);
  return <AsyncView state={report}>{(r) => <>
    <Stats items={[['Tổng lịch hẹn', r.totalAppointments], ['Tỉ lệ vắng mặt', percent(r.noShowRate), 'Vắng ÷ (đã tiếp nhận + vắng)', r.noShowRate > 0.2 ? 'red' : ''], ['Tỉ lệ hủy', percent(r.cancellationRate), 'Hủy ÷ tổng lịch hẹn']]} />
    <div className="ui-cols">
      <Panel title="Theo trạng thái" flush><Table caption="Lịch hẹn theo trạng thái" rowKey="key" rows={Object.entries(r.byStatus).map(([key, count]) => ({ key, count }))} columns={[{ title: 'Trạng thái', render: (row) => APPOINTMENT_STATUS[row.key]?.label || row.key }, { title: 'Số lịch', align: 'right', key: 'count' }]} /></Panel>
      <Panel title="Theo kênh đặt" flush><Table caption="Lịch hẹn theo kênh" rowKey="key" rows={Object.entries(r.byChannel).map(([key, count]) => ({ key, count }))} columns={[{ title: 'Kênh', render: (row) => BOOKING_CHANNEL[row.key] || row.key }, { title: 'Số lịch', align: 'right', key: 'count' }]} /></Panel>
    </div>
  </>}</AsyncView>;
}

export default function ReportsPage() {
  const [tab, setTab] = useState('revenue');
  const [from, setFrom] = useState(todayIso(-29));
  const [to, setTo] = useState(todayIso());
  const [groupBy, setGroupBy] = useState('DAY');
  const days = (new Date(to) - new Date(from)) / 86400000 + 1;
  const invalid = !from || !to || from > to ? 'Khoảng ngày không hợp lệ: ngày bắt đầu phải trước hoặc bằng ngày kết thúc.' : days > MAX_DAYS ? `Khoảng báo cáo tối đa ${MAX_DAYS} ngày.` : '';
  const [applied, setApplied] = useState({ fromDate: from, toDate: to });
  return <StaffLayout area="admin" title="Báo cáo & thống kê">
    <PageHead eyebrow="BÁO CÁO" title="Báo cáo & thống kê">Doanh thu, vận hành phòng khám và hiệu quả đặt lịch theo khoảng ngày (giờ Việt Nam). Mặc định 30 ngày gần nhất.</PageHead>
    <Panel>
      <div className="ui-toolbar" style={{ margin: 0, alignItems: 'flex-end' }}>
        <Field label="Từ ngày"><Input type="date" value={from} max={to} onChange={(event) => setFrom(event.target.value)} /></Field>
        <Field label="Đến ngày"><Input type="date" value={to} min={from} onChange={(event) => setTo(event.target.value)} /></Field>
        {tab === 'revenue' && <Field label="Nhóm theo"><Select value={groupBy} onChange={(event) => setGroupBy(event.target.value)}><option value="DAY">Ngày</option><option value="WEEK">Tuần</option><option value="MONTH">Tháng</option><option value="QUARTER">Quý</option></Select></Field>}
        <Button variant="primary" disabled={Boolean(invalid)} onClick={() => setApplied({ fromDate: from, toDate: to })}>Xem báo cáo</Button>
      </div>
      {invalid && <div className="ui-alert error" role="alert" style={{ marginTop: 12 }}><span>{invalid}</span></div>}
      <p className="ui-muted" style={{ fontSize: 12, marginBottom: 0 }}>Đang xem: {formatDate(applied.fromDate)} – {formatDate(applied.toDate)}</p>
    </Panel>
    <Tabs tabs={[{ key: 'revenue', label: 'Doanh thu' }, { key: 'operations', label: 'Vận hành' }, { key: 'appointments', label: 'Lịch hẹn' }]} value={tab} onChange={setTab} />
    {tab === 'revenue' && <Revenue range={applied} groupBy={groupBy} />}
    {tab === 'operations' && <Operations range={applied} />}
    {tab === 'appointments' && <Appointments range={applied} />}
  </StaffLayout>;
}
