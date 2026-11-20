import { useEffect, useState } from 'react';
import Modal from '../common/Modal';
import { PrescriptionView } from './MedicalEntry';
import { AsyncView, Badge, Button, ConfirmDialog, Facts, Field, Input, Notice, Panel, Table } from '../ui';
import { billingApi, pharmacyApi } from '../../api/endpoints';
import useAction from '../../hooks/useAction';
import useAsync from '../../hooks/useAsync';
import { formatDateTime, formatMoney } from '../../lib/format';
import { PAYMENT_STATUS } from '../../lib/labels';

const SELLABLE = ['WAITING_PAYMENT', 'COMPLETED'];

/** Tồn kho của một dòng thuốc kèm cảnh báo: hết hàng / còn dưới mức tối thiểu / số mua vượt tồn. */
function StockCell({ stock, minStock, quantity }) {
  const qty = Number(quantity);
  const over = Number.isFinite(qty) && qty > stock;
  const remaining = Number.isFinite(qty) && qty >= 0 ? stock - qty : stock;
  return <>
    <strong style={{ color: stock === 0 ? 'var(--ui-danger, #f87171)' : undefined }}>{stock === 0 ? 'Hết hàng' : stock}</strong>
    {over && <small style={{ color: 'var(--ui-danger, #f87171)' }}>Vượt tồn kho (tối đa {stock})</small>}
    {!over && stock > 0 && remaining < minStock && <small style={{ color: 'var(--ui-warning, #fbbf24)' }}>Sau khi bán còn {remaining}, dưới mức tối thiểu {minStock}</small>}
  </>;
}

/** In đơn cho khách mua thuốc ngoài (BR-32): không tạo hóa đơn, không đổi gì trong hệ thống. */
function PrintDialog({ prescriptionId, onClose }) {
  const printable = useAsync(() => pharmacyApi.printPrescription(prescriptionId), [prescriptionId]);
  return <Modal title="Đơn thuốc" id="print-prescription" onClose={onClose}>
    <AsyncView state={printable}>{(p) => <div className="ui-stack" style={{ gap: 12 }}>
      <p className="ui-confirm-text">{p.visitCode} · {p.petName} · Kê lúc {formatDateTime(p.createdAt)}</p>
      <PrescriptionView prescription={p} />
      <div className="ui-actions ui-no-print"><Button variant="primary" onClick={() => window.print()}>In đơn</Button><Button onClick={onClose}>Đóng</Button></div>
    </div>}</AsyncView>
  </Modal>;
}

/** Hóa đơn thuốc đã lập: sửa số lượng khi còn chờ thanh toán (xử lý thiếu kho), hủy khi khách đổi ý, thu tiền + trừ kho. */
function InvoiceEditor({ invoiceId, onChanged }) {
  const invoice = useAsync(() => billingApi.medicineInvoice(invoiceId), [invoiceId]);
  const [quantities, setQuantities] = useState({});
  const [discount, setDiscount] = useState('');
  const [dialog, setDialog] = useState(null);
  const action = useAction();
  const data = invoice.data;
  useEffect(() => {
    if (!data) return;
    setQuantities(Object.fromEntries(data.items.map((item) => [item.prescriptionItemId, String(item.quantity)])));
    setDiscount(String(data.discountAmount ?? 0));
  }, [data]);

  const reload = () => { invoice.refresh(); onChanged?.(); };
  const save = async () => {
    const items = data.items.map((item) => ({ prescriptionItemId: item.prescriptionItemId, quantity: Number(quantities[item.prescriptionItemId]) }));
    if (items.some((line) => !Number.isInteger(line.quantity) || line.quantity < 0)) { action.setNotice({ type: 'error', text: 'Số lượng phải là số nguyên không âm (0 = bỏ dòng khỏi hóa đơn).' }); return; }
    const tooMany = data.items.find((item) => Number(quantities[item.prescriptionItemId]) > item.stockQuantity);
    if (tooMany) { action.setNotice({ type: 'error', text: `Thuốc ${tooMany.medicineName} chỉ còn ${tooMany.stockQuantity} ${tooMany.unit} trong kho, không bán quá số này.` }); return; }
    if (await action.run(() => billingApi.updateMedicineInvoiceItems(invoiceId, { items, discountAmount: Number(discount) || 0 }), 'Đã cập nhật hóa đơn thuốc.')) reload();
  };

  return <AsyncView state={invoice}>{(inv) => {
    const pending = inv.paymentStatus === 'PENDING';
    return <div className="ui-stack" style={{ gap: 14 }}>
      <Notice notice={action.notice} onClose={action.clear} />
      <Facts items={[['Mã hóa đơn thuốc', inv.invoiceCode], ['Trạng thái', <Badge key="s" map={PAYMENT_STATUS} value={inv.paymentStatus} />], ['Trước VAT', formatMoney(inv.amountBeforeVat)], ['VAT', formatMoney(inv.vatAmount)], ['Giảm giá', formatMoney(inv.discountAmount)],
        ['Phải trả', <strong key="p">{formatMoney(inv.payableAmount)}</strong>], ['Thu lúc', formatDateTime(inv.paidAt)], ['Thu ngân', inv.cashierId ? `#${inv.cashierId}` : null]]} />
      <Table caption="Thuốc trong hóa đơn" rowKey="id" rows={inv.items} columns={[
        { title: 'Thuốc', render: (row) => <><strong>{row.medicineName}</strong><small>{row.medicineCode}</small></> },
        { title: 'Số lượng mua', render: (row) => (pending
          ? <div style={{ display: 'flex', gap: 8, alignItems: 'center' }}><Input type="number" min="0" max={row.stockQuantity} aria-label={`Số lượng ${row.medicineName}`} style={{ maxWidth: 90 }} value={quantities[row.prescriptionItemId] ?? ''} onChange={(event) => setQuantities({ ...quantities, [row.prescriptionItemId]: event.target.value })} /><span className="ui-muted">{row.unit} · bác sĩ kê {row.prescribedQuantity}</span></div>
          : `${row.quantity} ${row.unit} (bác sĩ kê ${row.prescribedQuantity})`) },
        ...(pending ? [{ title: 'Tồn kho', render: (row) => <StockCell stock={row.stockQuantity} minStock={row.minStockAlert} quantity={quantities[row.prescriptionItemId]} /> }] : []),
        { title: 'Đơn giá (đã chốt)', align: 'right', render: (row) => <>{formatMoney(row.unitPrice)}<small>VAT {Math.round(Number(row.vatRate) * 100)}%</small></> },
        { title: 'Thành tiền', align: 'right', render: (row) => formatMoney(Number(row.amountBeforeVat) + Number(row.vatAmount)) }]} />
      {pending && <>
        <Field label="Giảm giá (VND)" hint="Không vượt quá tổng tiền thuốc của hóa đơn này."><Input type="number" min="0" step="1000" style={{ maxWidth: 200 }} value={discount} onChange={(event) => setDiscount(event.target.value)} /></Field>
        <p className="ui-muted" style={{ margin: 0 }}>Số lượng bác sĩ kê chỉ để tham khảo: khách có thể mua nhiều hơn, ít hơn hoặc bằng, nhưng không quá tồn kho. Nếu kho vừa thay đổi và không đủ: sửa số lượng (0 để bỏ dòng) rồi thu lại.</p>
        <div className="ui-actions ui-no-print">
          <Button variant="primary" onClick={() => setDialog('pay')}>Thu tiền thuốc</Button>
          <Button busy={action.busy} onClick={save}>Lưu thay đổi</Button>
          <Button variant="danger" onClick={() => setDialog('cancel')}>Khách đổi ý — hủy hóa đơn</Button>
        </div></>}
      {inv.paymentStatus === 'CANCELLED' && <p className="ui-muted">Hóa đơn đã hủy. Hủy là kết thúc: đơn này không lập lại hóa đơn thuốc (khách có thể mua ngoài bằng đơn in).</p>}
      {dialog === 'pay' && <ConfirmDialog title="Thu tiền thuốc" confirmLabel="Đã thu tiền" onClose={() => setDialog(null)} onConfirm={async () => { await billingApi.confirmMedicinePayment(invoiceId); action.setNotice({ type: 'success', text: 'Đã thu tiền thuốc và trừ kho.' }); reload(); }}>
        Thu <strong>{formatMoney(inv.payableAmount)}</strong> cho hóa đơn {inv.invoiceCode}. Kho bị trừ ngay trong cùng thao tác và không hoàn tác được.</ConfirmDialog>}
      {dialog === 'cancel' && <ConfirmDialog title="Hủy hóa đơn thuốc" danger confirmLabel="Hủy hóa đơn" onClose={() => setDialog(null)} onConfirm={async () => { await billingApi.cancelMedicineInvoice(invoiceId); action.setNotice({ type: 'success', text: 'Đã hủy hóa đơn thuốc (kho không đổi).' }); reload(); }}>
        Khách không mua thuốc nữa. Kho không thay đổi. Đơn thuốc này sẽ không lập lại được hóa đơn thuốc.</ConfirmDialog>}
    </div>;
  }}</AsyncView>;
}

/**
 * Lập hóa đơn thuốc từ đơn: số lượng bác sĩ kê chỉ để THAM KHẢO. Khách mua nhiều hơn / ít hơn / bằng đều được, nhưng không quá tồn kho
 * (mua ngoài thì chỉ in đơn). Mức tồn tối thiểu chỉ cảnh báo, không chặn bán.
 */
function CreateInvoice({ prescription, visitStatus, onCreated }) {  // onCreated(text) chạy sau khi lập xong
  const [picked, setPicked] = useState(() => Object.fromEntries(prescription.items.map((item) => [item.id,
    { checked: item.stockQuantity > 0, quantity: String(Math.min(item.quantity, item.stockQuantity)) }])));
  const [discount, setDiscount] = useState('0');
  const action = useAction();
  const create = async () => {
    const chosen = prescription.items.filter((item) => picked[item.id]?.checked);
    const items = chosen.map((item) => ({ prescriptionItemId: item.id, quantity: Number(picked[item.id].quantity) }));
    if (!items.length) { action.setNotice({ type: 'error', text: 'Chọn ít nhất một thuốc khách mua tại phòng khám.' }); return; }
    if (items.some((line) => !Number.isInteger(line.quantity) || line.quantity < 1)) { action.setNotice({ type: 'error', text: 'Số lượng mua phải là số nguyên dương.' }); return; }
    const tooMany = chosen.find((item) => Number(picked[item.id].quantity) > item.stockQuantity);
    if (tooMany) { action.setNotice({ type: 'error', text: `Thuốc ${tooMany.medicineName} chỉ còn ${tooMany.stockQuantity} ${tooMany.unit} trong kho, không bán quá số này.` }); return; }
    if (await action.run(() => pharmacyApi.createMedicineInvoice(prescription.id, { items, discountAmount: Number(discount) || 0 }))) onCreated('Đã lập hóa đơn thuốc. Thu tiền thuốc để trừ kho.');
  };
  const set = (id, patch) => setPicked({ ...picked, [id]: { ...picked[id], ...patch } });
  return <div className="ui-stack" style={{ gap: 12 }}>
    <Notice notice={action.notice} onClose={action.clear} />
    {!SELLABLE.includes(visitStatus) && <div className="ui-alert warning" role="status"><span>Bác sĩ chưa chốt ca nên chưa lập hóa đơn thuốc được.</span></div>}
    <p className="ui-muted" style={{ margin: 0 }}>Số lượng bác sĩ kê chỉ để tham khảo: khách có thể mua nhiều hơn, ít hơn hoặc bằng, nhưng không quá tồn kho. Giá và VAT được chốt theo danh mục lúc lập hóa đơn; mua ngoài thì in đơn.</p>
    <div className="ui-table-scroll"><table className="ui-table">
      <caption className="ui-sr-only">Chọn thuốc khách mua tại phòng khám</caption>
      <thead><tr><th>Mua</th><th>Thuốc</th><th>Bác sĩ kê</th><th>Tồn kho</th><th>Số lượng mua</th></tr></thead>
      <tbody>{prescription.items.map((item) => {
        const soldOut = item.stockQuantity === 0;
        return <tr key={item.id}>
          <td><input type="checkbox" aria-label={`Mua ${item.medicineName}`} disabled={soldOut} checked={Boolean(picked[item.id]?.checked)} onChange={() => set(item.id, { checked: !picked[item.id]?.checked })} /></td>
          <td><strong>{item.medicineName}</strong>{item.activeIngredient && <small>{item.activeIngredient}</small>}</td>
          <td>{item.quantity} {item.unit}</td>
          <td><StockCell stock={item.stockQuantity} minStock={item.minStockAlert} quantity={picked[item.id]?.checked ? picked[item.id]?.quantity : 0} /></td>
          <td style={{ maxWidth: 150 }}>{soldOut ? <span className="ui-muted">Khách mua ngoài</span>
            : <Input type="number" min="1" max={item.stockQuantity} aria-label={`Số lượng mua ${item.medicineName}`} disabled={!picked[item.id]?.checked} value={picked[item.id]?.quantity ?? ''} onChange={(event) => set(item.id, { quantity: event.target.value })} />}</td>
        </tr>;
      })}</tbody>
    </table></div>
    <Field label="Giảm giá (VND)"><Input type="number" min="0" step="1000" style={{ maxWidth: 200 }} value={discount} onChange={(event) => setDiscount(event.target.value)} /></Field>
    <div className="ui-actions"><Button variant="primary" disabled={!SELLABLE.includes(visitStatus)} busy={action.busy} onClick={create}>Lập hóa đơn thuốc</Button></div>
  </div>;
}

/** Bán thuốc theo đơn của một đợt khám (UC-36). Hóa đơn thuốc độc lập với hóa đơn dịch vụ và không đổi trạng thái đợt khám. */
export default function MedicineSale({ visitId, visitStatus }) {
  const prescription = useAsync(() => pharmacyApi.prescriptionByVisit(visitId).catch((problem) => { if (problem.status === 404) return null; throw problem; }), [visitId]);
  const [printing, setPrinting] = useState(false);
  const [notice, setNotice] = useState(null);
  return <Panel title="Thuốc theo đơn" subtitle="Chỉ phát sinh hóa đơn khi khách chọn mua tại phòng khám. Mua ngoài: in đơn cho khách.">
    <AsyncView state={prescription} isEmpty={() => false}>{(p) => (p === null
      ? <p className="ui-muted">Bác sĩ không kê đơn thuốc cho đợt khám này.</p>
      : <div className="ui-stack" style={{ gap: 14 }}>
        <Notice notice={notice} onClose={() => setNotice(null)} />
        <PrescriptionView prescription={p} />
        <div className="ui-actions ui-no-print"><Button onClick={() => setPrinting(true)}>In đơn cho khách mua ngoài</Button></div>
        {p.medicineInvoiceId
          ? <InvoiceEditor invoiceId={p.medicineInvoiceId} onChanged={prescription.refresh} />
          : <CreateInvoice prescription={p} visitStatus={visitStatus} onCreated={(text) => { setNotice({ type: 'success', text }); prescription.refresh(); }} />}
        {printing && <PrintDialog prescriptionId={p.id} onClose={() => setPrinting(false)} />}
      </div>)}</AsyncView>
  </Panel>;
}
