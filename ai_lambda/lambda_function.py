import json
import boto3
import pyodbc
import logging
import os
from datetime import datetime, timedelta
from dateutil.parser import parse as parse_date
from typing import Dict, List, Any, Optional

# Configure logging
logger = logging.getLogger()
logger.setLevel(logging.INFO)

class CMDBChatBot:
    def __init__(self):
        self.bedrock = boto3.client('bedrock-runtime', region_name='us-east-1')
        self.secrets_client = boto3.client('secretsmanager')
        self.db_connection = None
        
        # Intent templates with parameterized queries
        self.intent_templates = {
            "MA_EXPIRING": {
                "description": "Thiết bị hết hạn bảo hành",
                "sql": """
                    SELECT TOP 100 Name, SerialNumber, MaEndDate, MaCost, Type
                    FROM dbo.Devices
                    WHERE MaEndDate >= ? AND MaEndDate < ?
                    ORDER BY MaEndDate ASC
                """,
                "params": ["start_date", "end_date"]
            },
            "MA_EXPIRED": {
                "description": "Thiết bị đã hết hạn bảo hành",
                "sql": """
                    SELECT TOP 100 Name, SerialNumber, MaEndDate, MaCost, Type
                    FROM dbo.Devices
                    WHERE MaEndDate < GETDATE()
                    ORDER BY MaEndDate DESC
                """,
                "params": []
            },
            "MA_COST_BY_MONTH": {
                "description": "Chi phí bảo hành theo tháng",
                "sql": """
                    SELECT 
                        YEAR(MaStartDate) as Year,
                        MONTH(MaStartDate) as Month,
                        COUNT(*) as DeviceCount,
                        SUM(MaCost) as TotalCost
                    FROM dbo.Devices
                    WHERE MaStartDate >= ? AND MaStartDate < ?
                    GROUP BY YEAR(MaStartDate), MONTH(MaStartDate)
                    ORDER BY Year DESC, Month DESC
                """,
                "params": ["start_date", "end_date"]
            },
            "DEVICES_BY_TYPE": {
                "description": "Thống kê thiết bị theo loại",
                "sql": """
                    SELECT 
                        Type,
                        COUNT(*) as DeviceCount,
                        AVG(MaCost) as AvgCost,
                        SUM(MaCost) as TotalCost
                    FROM dbo.Devices
                    WHERE Type LIKE ?
                    GROUP BY Type
                    ORDER BY DeviceCount DESC
                """,
                "params": ["device_type"]
            },
            "CHANGES_LAST_30D": {
                "description": "Thay đổi trong 30 ngày qua",
                "sql": """
                    SELECT TOP 100
                        dc.ChangedAt,
                        d.Name as DeviceName,
                        dc.Field,
                        dc.OldValue,
                        dc.NewValue,
                        dc.UserId
                    FROM dbo.DeviceChanges dc
                    JOIN dbo.Devices d ON dc.DeviceId = d.Id
                    WHERE dc.ChangedAt >= DATEADD(day, -30, GETDATE())
                    ORDER BY dc.ChangedAt DESC
                """,
                "params": []
            },
            "DEVICE_SEARCH": {
                "description": "Tìm kiếm thiết bị",
                "sql": """
                    SELECT TOP 50 
                        Name, SerialNumber, Type, MaStartDate, MaEndDate, MaCost
                    FROM dbo.Devices
                    WHERE Name LIKE ? OR SerialNumber LIKE ?
                    ORDER BY Name
                """,
                "params": ["search_term", "search_term"]
            }
        }

    def get_db_credentials(self) -> Dict[str, str]:
        """Get database credentials from Secrets Manager"""
        try:
            secret_name = os.environ.get('DB_SECRET_NAME', 'cmdb/db')
            response = self.secrets_client.get_secret_value(SecretId=secret_name)
            secret = json.loads(response['SecretString'])
            return secret
        except Exception as e:
            logger.error(f"Error getting DB credentials: {str(e)}")
            raise

    def connect_to_database(self) -> pyodbc.Connection:
        """Establish database connection"""
        if self.db_connection:
            try:
                # Test existing connection
                self.db_connection.execute("SELECT 1")
                return self.db_connection
            except:
                self.db_connection = None

        try:
            creds = self.get_db_credentials()
            
            connection_string = (
                f"DRIVER={{ODBC Driver 17 for SQL Server}};"
                f"SERVER={creds['host']};"
                f"DATABASE={creds['database']};"
                f"UID={creds['username']};"
                f"PWD={creds['password']};"
                f"Encrypt=yes;"
                f"TrustServerCertificate=yes;"
                f"Connection Timeout=30;"
            )
            
            self.db_connection = pyodbc.connect(connection_string)
            logger.info("Database connection established")
            return self.db_connection
            
        except Exception as e:
            logger.error(f"Database connection failed: {str(e)}")
            raise

    def parse_intent_with_bedrock(self, user_query: str) -> Dict[str, Any]:
        """Use Bedrock to parse user intent and extract parameters"""
        
        # Create intent descriptions for the prompt
        intent_descriptions = {}
        for intent, config in self.intent_templates.items():
            intent_descriptions[intent] = config["description"]
        
        prompt = f"""
Bạn là một AI assistant cho hệ thống CMDB (Configuration Management Database).
Hãy phân tích câu hỏi của người dùng và trả về JSON với intent và parameters.

Danh sách intent có thể:
{json.dumps(intent_descriptions, ensure_ascii=False, indent=2)}

Câu hỏi: "{user_query}"

Hãy trả về JSON theo format:
{{
    "intent": "TÊN_INTENT",
    "params": {{
        "param_name": "value"
    }},
    "confidence": 0.8
}}

Lưu ý:
- Nếu hỏi về "hết hạn" hoặc "expiring", dùng MA_EXPIRING
- Nếu hỏi về "đã hết hạn" hoặc "expired", dùng MA_EXPIRED  
- Nếu hỏi về chi phí theo thời gian, dùng MA_COST_BY_MONTH
- Nếu hỏi về loại thiết bị, dùng DEVICES_BY_TYPE
- Nếu hỏi về thay đổi gần đây, dùng CHANGES_LAST_30D
- Nếu tìm kiếm tên/serial, dùng DEVICE_SEARCH

Với thời gian:
- "tháng này" = tháng hiện tại
- "tháng tới" = tháng tiếp theo
- "30 ngày" = 30 ngày từ hôm nay
- Định dạng ngày: YYYY-MM-DD

JSON response:
"""

        try:
            # Use Claude 3 Haiku for intent parsing
            response = self.bedrock.invoke_model(
                modelId='anthropic.claude-3-haiku-20240307-v1:0',
                body=json.dumps({
                    "anthropic_version": "bedrock-2023-05-31",
                    "max_tokens": 500,
                    "messages": [
                        {
                            "role": "user",
                            "content": prompt
                        }
                    ]
                })
            )
            
            response_body = json.loads(response['body'].read())
            content = response_body['content'][0]['text']
            
            # Extract JSON from response
            json_start = content.find('{')
            json_end = content.rfind('}') + 1
            if json_start >= 0 and json_end > json_start:
                intent_json = json.loads(content[json_start:json_end])
                return intent_json
            else:
                raise ValueError("No valid JSON found in response")
                
        except Exception as e:
            logger.error(f"Bedrock intent parsing failed: {str(e)}")
            # Fallback to simple keyword matching
            return self.fallback_intent_parsing(user_query)

    def fallback_intent_parsing(self, user_query: str) -> Dict[str, Any]:
        """Simple keyword-based intent parsing as fallback"""
        query_lower = user_query.lower()
        
        if any(word in query_lower for word in ["hết hạn", "expiring", "sắp hết"]):
            return {"intent": "MA_EXPIRING", "params": {}, "confidence": 0.6}
        elif any(word in query_lower for word in ["đã hết", "expired"]):
            return {"intent": "MA_EXPIRED", "params": {}, "confidence": 0.6}
        elif any(word in query_lower for word in ["chi phí", "cost", "tiền"]):
            return {"intent": "MA_COST_BY_MONTH", "params": {}, "confidence": 0.6}
        elif any(word in query_lower for word in ["loại", "type", "thống kê"]):
            return {"intent": "DEVICES_BY_TYPE", "params": {"device_type": "%"}, "confidence": 0.6}
        elif any(word in query_lower for word in ["thay đổi", "change", "lịch sử"]):
            return {"intent": "CHANGES_LAST_30D", "params": {}, "confidence": 0.6}
        else:
            return {"intent": "DEVICE_SEARCH", "params": {"search_term": f"%{user_query}%"}, "confidence": 0.5}

    def prepare_query_params(self, intent: str, params: Dict[str, Any]) -> List[Any]:
        """Prepare parameters for SQL query"""
        template = self.intent_templates.get(intent)
        if not template:
            return []
        
        query_params = []
        for param_name in template["params"]:
            if param_name in params:
                query_params.append(params[param_name])
            elif param_name in ["start_date", "end_date"]:
                # Default date ranges
                now = datetime.now()
                if param_name == "start_date":
                    query_params.append(now.strftime('%Y-%m-%d'))
                else:
                    query_params.append((now + timedelta(days=30)).strftime('%Y-%m-%d'))
            elif param_name == "device_type":
                query_params.append("%")
            elif param_name == "search_term":
                query_params.append("%")
            else:
                query_params.append("")
                
        return query_params

    def execute_query(self, intent: str, params: Dict[str, Any]) -> Dict[str, Any]:
        """Execute SQL query based on intent and parameters"""
        try:
            template = self.intent_templates.get(intent)
            if not template:
                return {"error": f"Unknown intent: {intent}"}
            
            conn = self.connect_to_database()
            cursor = conn.cursor()
            
            # Prepare parameters
            query_params = self.prepare_query_params(intent, params)
            
            # Execute query
            cursor.execute(template["sql"], query_params)
            
            # Fetch results
            columns = [column[0] for column in cursor.description]
            rows = []
            
            # Limit results to prevent large responses
            max_rows = 500
            for i, row in enumerate(cursor.fetchall()):
                if i >= max_rows:
                    break
                    
                row_dict = {}
                for j, value in enumerate(row):
                    # Convert datetime objects to strings
                    if isinstance(value, datetime):
                        row_dict[columns[j]] = value.isoformat()
                    else:
                        row_dict[columns[j]] = value
                rows.append(row_dict)
            
            return {
                "intent": intent,
                "description": template["description"],
                "columns": columns,
                "rows": rows,
                "row_count": len(rows),
                "truncated": len(rows) >= max_rows
            }
            
        except Exception as e:
            logger.error(f"Query execution failed: {str(e)}")
            return {"error": f"Database query failed: {str(e)}"}

def lambda_handler(event, context):
    """Main Lambda handler"""
    try:
        # Parse request body
        if isinstance(event.get('body'), str):
            body = json.loads(event['body'])
        else:
            body = event.get('body', {})
        
        user_query = body.get('query', '')
        if not user_query:
            return {
                'statusCode': 400,
                'headers': {
                    'Content-Type': 'application/json',
                    'Access-Control-Allow-Origin': '*',
                    'Access-Control-Allow-Methods': 'POST, OPTIONS',
                    'Access-Control-Allow-Headers': 'Content-Type'
                },
                'body': json.dumps({'error': 'Query parameter is required'})
            }
        
        # Initialize chatbot
        chatbot = CMDBChatBot()
        
        # Parse intent
        logger.info(f"Processing query: {user_query}")
        intent_result = chatbot.parse_intent_with_bedrock(user_query)
        
        if intent_result.get('confidence', 0) < 0.3:
            return {
                'statusCode': 200,
                'headers': {
                    'Content-Type': 'application/json',
                    'Access-Control-Allow-Origin': '*',
                    'Access-Control-Allow-Methods': 'POST, OPTIONS',
                    'Access-Control-Allow-Headers': 'Content-Type'
                },
                'body': json.dumps({
                    'message': 'Xin lỗi, tôi không hiểu câu hỏi của bạn. Hãy thử hỏi về thiết bị, bảo hành, hoặc thống kê.',
                    'suggestions': [
                        'Thiết bị nào sắp hết hạn bảo hành?',
                        'Chi phí bảo hành tháng này',
                        'Thống kê thiết bị theo loại',
                        'Thay đổi gần đây'
                    ]
                })
            }
        
        # Execute query
        result = chatbot.execute_query(
            intent_result['intent'], 
            intent_result.get('params', {})
        )
        
        return {
            'statusCode': 200,
            'headers': {
                'Content-Type': 'application/json',
                'Access-Control-Allow-Origin': '*',
                'Access-Control-Allow-Methods': 'POST, OPTIONS',
                'Access-Control-Allow-Headers': 'Content-Type'
            },
            'body': json.dumps(result, ensure_ascii=False)
        }
        
    except Exception as e:
        logger.error(f"Lambda handler error: {str(e)}")
        return {
            'statusCode': 500,
            'headers': {
                'Content-Type': 'application/json',
                'Access-Control-Allow-Origin': '*',
                'Access-Control-Allow-Methods': 'POST, OPTIONS', 
                'Access-Control-Allow-Headers': 'Content-Type'
            },
            'body': json.dumps({'error': 'Internal server error'})
        }
