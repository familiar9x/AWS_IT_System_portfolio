1) Hạ tầng mới (Infra)

API Gateway (HTTP API): 1 endpoint POST /ask cho FE gọi.

Lambda “sql-assistant” (container image):

Runtime: Python (pyodbc) hoặc Node.js (mssql).

Image có msodbcsql17 (SQL Server ODBC driver).

VPC config: chạy trong private subnets, SG mở outbound 1433 tới SG-RDS.

CloudWatch Logs (log prompt/intent/template ID, không log secrets).

Secrets Manager: 1 secret cmdb/db chứa DB_HOST, DB_USER_RO, DB_PASS, DB_NAME.

(Nếu bạn đang “no-NAT”) VPC Endpoints để Lambda đi nội mạng AWS:

Interface: secretsmanager, logs, (tuỳ kms, sts).

Gateway: S3 (nếu image pull hoặc code cần S3).

(Tuỳ chọn): SQS DLQ cho API Gateway/Lambda nếu muốn retry/queuing.

2) Quyền & bảo mật (IAM/SG)

Lambda execution role:

secretsmanager:GetSecretValue (giới hạn đúng ARN secret).

bedrock:InvokeModel (model bạn chọn, region hỗ trợ Bedrock).

logs:CreateLogGroup/Stream, logs:PutLogEvents.

Kết nối DB an toàn:

Tạo user READONLY trong RDS SQL Server; chỉ SELECT các view bạn cho phép.

SG-RDS: ingress 1433 từ SG-Lambda (thêm rule).

Guardrails:

Không cho LLM sinh SQL tự do. Chỉ trả intent + params (JSON) → bạn map vào template SQL.

3) Ứng dụng (Code) trong Lambda

Intent Router (Bedrock):

Prompt ép mô hình trả JSON: { "intent": "...", "params": {...} }.

Danh mục intent whitelist (ví dụ):
MA_EXPIRING, MA_COST_BY_MONTH, DEVICES_BY_TYPE, CHANGES_LAST_30D, …

SQL Templates (tham số hoá, không string-concat):

Ví dụ MA_EXPIRING:

SELECT TOP 100 Name, SerialNumber, MaEndDate, MaCost
FROM dbo.Devices
WHERE MaEndDate >= @start AND MaEndDate < @end
ORDER BY MaEndDate ASC


Kết nối DB:

Lấy secrets → kết nối pyodbc/mssql với timeout (30–60s), TOP/LIMIT đầu ra.

Cắt dữ liệu trả về (vd tối đa 500 dòng).

Schema/View gợi ý trong RDS:

dbo.Devices (Name, SerialNumber, Type, MaStartDate, MaEndDate, MaCost, …)

dbo.DeviceChanges (DeviceId, ChangedAt, Field, OldValue, NewValue, UserId, …)

dbo.v_MA_Expired (view tiện lợi cho intent “hết hạn”).

4) Tích hợp FE (React)

Chat/Ask widget gọi API Gateway /ask:

Gửi JSON { "query": "…" }, nhận { intent, rows }.

Cho phép “quick filters” (tháng/năm/loại thiết bị).

Env: VITE_AI_API=https://<api-gw-domain>/ask (nếu muốn tách khỏi CF),
hoặc route qua CloudFront (multi-origin) như /ai/ask → origin API GW.

5) Quan sát & vận hành

Logs: CloudWatch (Lambda + API GW access logs).

Alarms: error rate của Lambda, 5xx của API GW.

Budget/Cost: Bedrock usage, Lambda duration, API GW requests.

6) Trình tự làm việc (từng bước)

RDS: tạo user cmdb_ro + các VIEW phục vụ báo cáo.

Secrets Manager: tạo secret cmdb/db.

Lambda container: Dockerfile cài msodbcsql17 + pyodbc (hoặc Node+mssql); code intent→template.

IAM: role cho Lambda (Bedrock + Secrets + Logs).

Networking: gắn Lambda vào private subnets; SG mở 1433 tới SG-RDS; (no-NAT) tạo VPC Endpoints cần thiết.

API Gateway: tạo /ask → Lambda proxy; bật CORS nếu gọi trực tiếp từ FE.

CloudFront (tuỳ chọn): route /ai/* tới API GW để 1 domain.

FE: thêm UI hỏi đáp + cấu hình endpoint.

Test: câu hỏi mẫu (“Thiết bị hết MA trong tháng này”, “Tổng chi phí MA theo quý…”) → kiểm tra logs, hiệu năng.

Hardening: thêm DLQ, rate limit API GW, guardrails intent, hạn mức Bedrock.