import React, { useState, useEffect, useRef } from 'react';
import { Send, Database, MessageCircle, BarChart3, Settings } from 'lucide-react';
import axios from 'axios';

// Configuration - Use CloudFront paths for seamless routing
const API_CONFIG = {
  AI_ENDPOINT: import.meta.env.VITE_AI_API_URL || '/ai/ask',  // CloudFront routes to API Gateway
  CMDB_API: import.meta.env.VITE_API_URL || '/api',           // CloudFront routes to ALB
  TIMEOUT: 30000
};

const QUICK_QUESTIONS = [
  'Thiết bị nào sắp hết hạn bảo hành trong tháng này?',
  'Tổng chi phí bảo hành trong quý này',
  'Thống kê thiết bị theo loại',
  'Thiết bị nào đã hết hạn bảo hành?',
  'Thay đổi gần đây trong hệ thống',
  'Tìm thiết bị WEB-SERVER'
];

function App() {
  const [messages, setMessages] = useState([]);
  const [inputValue, setInputValue] = useState('');
  const [isLoading, setIsLoading] = useState(false);
  const [apiStatus, setApiStatus] = useState({ cmdb: 'unknown', ai: 'unknown' });
  const messagesEndRef = useRef(null);

  const scrollToBottom = () => {
    messagesEndRef.current?.scrollIntoView({ behavior: 'smooth' });
  };

  useEffect(() => {
    scrollToBottom();
  }, [messages]);

  useEffect(() => {
    checkApiStatus();
    // Add welcome message
    setMessages([{
      id: 1,
      type: 'assistant',
      content: 'Xin chào! Tôi là AI Assistant của hệ thống CMDB. Bạn có thể hỏi tôi về thiết bị, bảo hành, thống kê và nhiều thông tin khác. Hãy thử một trong những câu hỏi mẫu bên dưới!',
      timestamp: new Date()
    }]);
  }, []);

  const checkApiStatus = async () => {
    // Check CMDB API
    try {
      await axios.get(`${API_CONFIG.CMDB_API}/health`, { timeout: 5000 });
      setApiStatus(prev => ({ ...prev, cmdb: 'online' }));
    } catch (error) {
      setApiStatus(prev => ({ ...prev, cmdb: 'offline' }));
    }

    // Check AI API (simple ping)
    try {
      await axios.post(API_CONFIG.AI_ENDPOINT, 
        { query: 'test' }, 
        { timeout: 5000 }
      );
      setApiStatus(prev => ({ ...prev, ai: 'online' }));
    } catch (error) {
      setApiStatus(prev => ({ ...prev, ai: 'offline' }));
    }
  };

  const sendMessage = async (message = inputValue) => {
    if (!message.trim() || isLoading) return;

    const userMessage = {
      id: Date.now(),
      type: 'user',
      content: message.trim(),
      timestamp: new Date()
    };

    setMessages(prev => [...prev, userMessage]);
    setInputValue('');
    setIsLoading(true);

    try {
      const response = await axios.post(
        API_CONFIG.AI_ENDPOINT,
        { query: message.trim() },
        {
          timeout: API_CONFIG.TIMEOUT,
          headers: {
            'Content-Type': 'application/json'
          }
        }
      );

      const aiResponse = {
        id: Date.now() + 1,
        type: 'assistant',
        content: response.data,
        timestamp: new Date()
      };

      setMessages(prev => [...prev, aiResponse]);
    } catch (error) {
      console.error('AI API Error:', error);
      
      let errorMessage = 'Xin lỗi, có lỗi xảy ra khi xử lý câu hỏi của bạn.';
      
      if (error.code === 'ECONNABORTED') {
        errorMessage = 'Timeout: Câu hỏi phức tạp quá, vui lòng thử lại với câu hỏi đơn giản hơn.';
      } else if (error.response?.status === 500) {
        errorMessage = 'Lỗi server: Hệ thống AI đang gặp sự cố, vui lòng thử lại sau.';
      } else if (error.response?.status === 400) {
        errorMessage = 'Câu hỏi không hợp lệ. Hãy thử hỏi về thiết bị, bảo hành hoặc thống kê.';
      }

      const errorResponse = {
        id: Date.now() + 1,
        type: 'assistant',
        content: { error: errorMessage },
        timestamp: new Date()
      };

      setMessages(prev => [...prev, errorResponse]);
    } finally {
      setIsLoading(false);
    }
  };

  const handleSubmit = (e) => {
    e.preventDefault();
    sendMessage();
  };

  const handleQuickQuestion = (question) => {
    sendMessage(question);
  };

  const renderMessageContent = (content) => {
    if (typeof content === 'string') {
      return <div>{content}</div>;
    }

    if (content.error) {
      return <div className="error">{content.error}</div>;
    }

    if (content.message) {
      return (
        <div>
          <div>{content.message}</div>
          {content.suggestions && (
            <div style={{ marginTop: '1rem' }}>
              <strong>Gợi ý:</strong>
              <ul style={{ marginTop: '0.5rem', paddingLeft: '1.5rem' }}>
                {content.suggestions.map((suggestion, index) => (
                  <li key={index} style={{ marginBottom: '0.25rem' }}>
                    <button 
                      className="quick-button"
                      onClick={() => handleQuickQuestion(suggestion)}
                      style={{ display: 'inline', padding: '0.25rem 0.5rem', margin: '0.25rem 0' }}
                    >
                      {suggestion}
                    </button>
                  </li>
                ))}
              </ul>
            </div>
          )}
        </div>
      );
    }

    if (content.rows && Array.isArray(content.rows)) {
      return (
        <div>
          <div style={{ marginBottom: '1rem' }}>
            <strong>{content.description || content.intent}</strong>
            {content.row_count && (
              <div style={{ fontSize: '0.9rem', color: '#666', marginTop: '0.25rem' }}>
                Tìm thấy {content.row_count} kết quả
                {content.truncated && ' (đã giới hạn hiển thị)'}
              </div>
            )}
          </div>
          
          {content.rows.length > 0 ? (
            <div style={{ overflowX: 'auto' }}>
              <table className="data-table">
                <thead>
                  <tr>
                    {content.columns?.map((column, index) => (
                      <th key={index}>{column}</th>
                    )) || Object.keys(content.rows[0]).map((key, index) => (
                      <th key={index}>{key}</th>
                    ))}
                  </tr>
                </thead>
                <tbody>
                  {content.rows.slice(0, 50).map((row, index) => (
                    <tr key={index}>
                      {(content.columns || Object.keys(row)).map((column, colIndex) => (
                        <td key={colIndex}>
                          {row[column] !== null && row[column] !== undefined 
                            ? String(row[column]) 
                            : '-'
                          }
                        </td>
                      ))}
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          ) : (
            <div style={{ padding: '2rem', textAlign: 'center', color: '#666' }}>
              Không tìm thấy dữ liệu nào
            </div>
          )}
        </div>
      );
    }

    return <div>{JSON.stringify(content, null, 2)}</div>;
  };

  return (
    <div className="container">
      <header className="header">
        <h1>CMDB AI Assistant</h1>
        <p>Hỏi đáp thông minh về hệ thống quản lý cấu hình</p>
      </header>

      <div className="dashboard">
        <div className="card">
          <h3><Database size={20} style={{ display: 'inline', marginRight: '0.5rem' }} />Trạng thái hệ thống</h3>
          <div style={{ display: 'flex', flexDirection: 'column', gap: '0.5rem' }}>
            <div style={{ display: 'flex', alignItems: 'center', gap: '0.5rem' }}>
              <span>CMDB API:</span>
              <span style={{ 
                color: apiStatus.cmdb === 'online' ? '#28a745' : '#dc3545',
                fontWeight: 'bold'
              }}>
                {apiStatus.cmdb === 'online' ? '🟢 Online' : '🔴 Offline'}
              </span>
            </div>
            <div style={{ display: 'flex', alignItems: 'center', gap: '0.5rem' }}>
              <span>AI Assistant:</span>
              <span style={{ 
                color: apiStatus.ai === 'online' ? '#28a745' : '#dc3545',
                fontWeight: 'bold'
              }}>
                {apiStatus.ai === 'online' ? '🟢 Online' : '🔴 Offline'}
              </span>
            </div>
          </div>
        </div>

        <div className="card">
          <h3><BarChart3 size={20} style={{ display: 'inline', marginRight: '0.5rem' }} />Thống kê</h3>
          <div style={{ fontSize: '0.9rem', color: '#666' }}>
            <div>Tổng tin nhắn: {messages.length}</div>
            <div>Phiên chat hiện tại</div>
            <div>AI Engine: Claude 3 Haiku</div>
          </div>
        </div>

        <div className="card ai-chat">
          <h3>
            <MessageCircle size={20} style={{ display: 'inline', marginRight: '0.5rem' }} />
            AI Chat Assistant
          </h3>
          
          <div className="quick-questions">
            <h4>Câu hỏi mẫu:</h4>
            <div className="quick-buttons">
              {QUICK_QUESTIONS.map((question, index) => (
                <button
                  key={index}
                  className="quick-button"
                  onClick={() => handleQuickQuestion(question)}
                  disabled={isLoading}
                >
                  {question}
                </button>
              ))}
            </div>
          </div>

          <div className="chat-container">
            <div className="chat-messages">
              {messages.map((message) => (
                <div key={message.id} className={`message ${message.type}`}>
                  <div className="message-content">
                    {renderMessageContent(message.content)}
                  </div>
                  <div style={{ 
                    fontSize: '0.75rem', 
                    color: '#666', 
                    marginTop: '0.25rem',
                    textAlign: message.type === 'user' ? 'right' : 'left'
                  }}>
                    {message.timestamp.toLocaleTimeString()}
                  </div>
                </div>
              ))}
              
              {isLoading && (
                <div className="message assistant">
                  <div className="message-content">
                    <div className="loading">
                      <div className="spinner"></div>
                      Đang xử lý câu hỏi...
                    </div>
                  </div>
                </div>
              )}
              
              <div ref={messagesEndRef} />
            </div>

            <form onSubmit={handleSubmit} className="chat-input-container">
              <input
                type="text"
                value={inputValue}
                onChange={(e) => setInputValue(e.target.value)}
                placeholder="Hỏi về thiết bị, bảo hành, thống kê..."
                className="chat-input"
                disabled={isLoading}
              />
              <button 
                type="submit" 
                className="send-button"
                disabled={isLoading || !inputValue.trim()}
              >
                <Send size={16} />
              </button>
            </form>
          </div>
        </div>
      </div>
    </div>
  );
}

export default App;
