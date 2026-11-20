import { useState } from 'react';
import { Link } from 'react-router-dom';
import StaffLayout from '../../layouts/StaffLayout';
import { AsyncView, Badge, Button, FormDialog, PageHead, Pager, Panel, Table } from '../../components/ui';
import { pharmacyApi } from '../../api/endpoints';
import { PrescriptionView } from '../../components/shared/MedicalEntry';
import { useNotificationEvents } from '../../contexts/NotificationContext';
import useAsync from '../../hooks/useAsync';
import { formatDateTime } from '../../lib/format';
import { PAYMENT_STATUS } from '../../lib/labels';

function DetailDialog({ id, onClose }) {
  const detail = useAsync(() => pharmacyApi.prescription(id), [id]);
  return <FormDialog title="Chi tiết đơn thuốc" onClose={onClose} onSubmit={async () => {}} submitLabel="Đóng" wide>
    <AsyncView state={detail}>{(p) => <div className="ui-stack" style={{ gap: 14 }}>
      <p className="ui-confirm-text">{p.visitCode} · {p.petName} · Kê lúc {formatDateTime(p.createdAt)} {p.medicineInvoiceStatus ? <>· Hóa đơn thuốc: <Badge map={PAYMENT_STATUS} value={p.medicineInvoiceStatus} /></> : '· Chưa lập hóa đơn thuốc'}</p>
      <PrescriptionView prescription={p} />
      <div className="ui-actions"><Link className="ui-button primary" to={`/reception/invoices/${p.visitId}`}>Mở bán thuốc / thu tiền</Link></div>
    </div>}</AsyncView>
  </FormDialog>;
}

/**
 * Bán thuốc theo đơn (v3.0): đơn thuốc chỉ là chỉ định chuyên môn (không giá, không trạng thái). Danh sách này giúp tìm đơn;
 * việc lập hóa đơn thuốc, sửa, hủy và thu tiền + trừ kho làm ở trang chi tiết của đợt khám (mục Hóa đơn &amp; thanh toán).
 */
export default function DispensePage() {
  const [page, setPage] = useState(0);
  const [detail, setDetail] = useState(null);
  const list = useAsync(() => pharmacyApi.prescriptions({ page, size: 20 }), [page]);
  useNotificationEvents(() => list.refresh(), ['VISIT_COMPLETED', 'MEDICINE_INVOICE_PAID']);

  return <StaffLayout area="reception" title="Bán thuốc">
    <PageHead eyebrow="QUẦY THUỐC" title="Bán thuốc theo đơn" actions={<Button onClick={list.reload}>Làm mới</Button>}>
      Khách có thể mua một phần hoặc toàn bộ đơn tại phòng khám, hoặc mua ngoài (in đơn). Hóa đơn thuốc độc lập với hóa đơn dịch vụ; thu tiền thuốc sẽ trừ kho trong cùng thao tác.
    </PageHead>
    <Panel flush>
      <AsyncView state={list} isEmpty={(data) => data.items.length === 0} empty="Chưa có đơn thuốc nào.">
        {(data) => <>
          <Table caption="Đơn thuốc" rows={data.items} columns={[
            { title: 'Đợt khám', render: (row) => <><strong>{row.visitCode || `#${row.visitId}`}</strong><small>{row.petName}</small></> },
            { title: 'Số loại thuốc', key: 'itemCount' },
            { title: 'Kê lúc', render: (row) => formatDateTime(row.createdAt) },
            { title: '', align: 'right', render: (row) => <div className="ui-actions" style={{ justifyContent: 'flex-end' }}>
              <Button className="small" onClick={() => setDetail(row.id)}>Chi tiết</Button>
              <Link className="ui-button small primary" to={`/reception/invoices/${row.visitId}`}>Bán thuốc</Link></div> }]} />
          <Pager page={data} onChange={setPage} />
        </>}
      </AsyncView>
    </Panel>
    {detail && <DetailDialog id={detail} onClose={() => setDetail(null)} />}
  </StaffLayout>;
}
