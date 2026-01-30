import { useState, useRef, useEffect } from 'react'
import { useQueryClient } from '@tanstack/react-query'
import { MessageCircle, X, Send, Bot, User, Loader2 } from 'lucide-react'
import api from '../lib/api'

export default function ChatBot() {
    const queryClient = useQueryClient()
    const [isOpen, setIsOpen] = useState(false)
    const [messages, setMessages] = useState([
        {
            role: 'assistant',
            content: 'Hey! Mình là FinBot, bạn thân tài chính của cậu đây.\n\nCậu có thể nhắn kiểu "50k cafe" hay "lương 15tr" để mình ghi giúp, hoặc hỏi gì về tiền nong cũng được nha!'
        }
    ])
    const [input, setInput] = useState('')
    const [isLoading, setIsLoading] = useState(false)
    const [conversationId, setConversationId] = useState(null)
    const messagesEndRef = useRef(null)

    const scrollToBottom = () => {
        messagesEndRef.current?.scrollIntoView({ behavior: 'smooth' })
    }

    useEffect(() => {
        scrollToBottom()
    }, [messages])

    // Refresh dashboard data - force refetch immediately
    const refreshDashboard = async () => {
        console.log('🔄 Refreshing dashboard data...')
        
        // Invalidate tất cả queries liên quan
        await queryClient.invalidateQueries({ queryKey: ['summary'] })
        await queryClient.invalidateQueries({ queryKey: ['byCategory'] })
        await queryClient.invalidateQueries({ queryKey: ['healthScore'] })
        await queryClient.invalidateQueries({ queryKey: ['anomalies'] })
        await queryClient.invalidateQueries({ queryKey: ['trend'] })
        await queryClient.invalidateQueries({ queryKey: ['insights'] })
        await queryClient.invalidateQueries({ queryKey: ['savings'] })
        await queryClient.invalidateQueries({ queryKey: ['smartBudget'] })
        
        console.log('✅ Dashboard refreshed!')
    }

    const handleSend = async () => {
        if (!input.trim() || isLoading) return

        const userMessage = input.trim()
        setInput('')

        // Add user message
        setMessages(prev => [...prev, { role: 'user', content: userMessage }])
        setIsLoading(true)

        try {
            const response = await api.post('/chat', {
                message: userMessage,
                conversationId
            })

            if (response.data.success) {
                setMessages(prev => [...prev, {
                    role: 'assistant',
                    content: response.data.data.message
                }])
                setConversationId(response.data.data.conversationId)
                
                // Nếu AI tạo giao dịch, refresh dashboard
                console.log('📊 Chat response:', response.data.data)
                if (response.data.data.transactionCreated) {
                    console.log('✅ Transaction created!', response.data.data.transactionCreated)
                    
                    // Thêm message thông báo đang cập nhật
                    setMessages(prev => [...prev, {
                        role: 'assistant',
                        content: '🔄 Đang cập nhật số dư...'
                    }])
                    
                    // Delay để DB cập nhật xong, sau đó refresh
                    setTimeout(async () => {
                        await refreshDashboard()
                        // Xóa message loading
                        setMessages(prev => prev.filter(m => m.content !== '🔄 Đang cập nhật số dư...'))
                    }, 1000) // Tăng delay lên 1s
                }
            } else {
                throw new Error(response.data.error)
            }
        } catch (error) {
            console.error('Chat error:', error)
            setMessages(prev => [...prev, {
                role: 'assistant',
                content: 'Xin lỗi, có lỗi xảy ra. Vui lòng thử lại sau.'
            }])
        } finally {
            setIsLoading(false)
        }
    }

    const handleKeyPress = (e) => {
        if (e.key === 'Enter' && !e.shiftKey) {
            e.preventDefault()
            handleSend()
        }
    }

    return (
        <>
            {/* Floating Button */}
            <button
                onClick={() => setIsOpen(!isOpen)}
                className={`fixed bottom-6 right-6 w-14 h-14 rounded-full shadow-lg flex items-center justify-center transition-all duration-300 z-50 ${isOpen
                        ? 'bg-gray-600 hover:bg-gray-700'
                        : 'bg-gradient-to-r from-blue-500 to-purple-600 hover:from-blue-600 hover:to-purple-700'
                    }`}
            >
                {isOpen ? (
                    <X className="w-6 h-6 text-white" />
                ) : (
                    <MessageCircle className="w-6 h-6 text-white" />
                )}
            </button>

            {/* Chat Window */}
            {isOpen && (
                <div className="fixed bottom-24 right-6 w-96 h-[500px] bg-white rounded-2xl shadow-2xl flex flex-col overflow-hidden z-50 animate-in slide-in-from-bottom-5">
                    {/* Header */}
                    <div className="bg-gradient-to-r from-blue-500 to-purple-600 px-4 py-3 flex items-center gap-3">
                        <div className="w-10 h-10 bg-white/20 rounded-full flex items-center justify-center">
                            <Bot className="w-6 h-6 text-white" />
                        </div>
                        <div>
                            <h3 className="text-white font-semibold">FinBot</h3>
                            <p className="text-white/80 text-xs">Trợ lý tài chính AI</p>
                        </div>
                    </div>

                    {/* Messages */}
                    <div className="flex-1 overflow-y-auto p-4 space-y-4 bg-gray-50">
                        {messages.map((message, index) => (
                            <div
                                key={index}
                                className={`flex gap-2 ${message.role === 'user' ? 'justify-end' : 'justify-start'}`}
                            >
                                {message.role === 'assistant' && (
                                    <div className="w-8 h-8 bg-gradient-to-r from-blue-500 to-purple-600 rounded-full flex items-center justify-center flex-shrink-0">
                                        <Bot className="w-4 h-4 text-white" />
                                    </div>
                                )}
                                <div
                                    className={`max-w-[75%] px-4 py-2 rounded-2xl whitespace-pre-wrap ${message.role === 'user'
                                            ? 'bg-blue-500 text-white rounded-br-md'
                                            : 'bg-white text-gray-800 shadow-sm rounded-bl-md'
                                        }`}
                                >
                                    {message.content}
                                </div>
                                {message.role === 'user' && (
                                    <div className="w-8 h-8 bg-gray-300 rounded-full flex items-center justify-center flex-shrink-0">
                                        <User className="w-4 h-4 text-gray-600" />
                                    </div>
                                )}
                            </div>
                        ))}
                        {isLoading && (
                            <div className="flex gap-2 justify-start">
                                <div className="w-8 h-8 bg-gradient-to-r from-blue-500 to-purple-600 rounded-full flex items-center justify-center">
                                    <Bot className="w-4 h-4 text-white" />
                                </div>
                                <div className="bg-white px-4 py-2 rounded-2xl rounded-bl-md shadow-sm">
                                    <Loader2 className="w-5 h-5 animate-spin text-blue-500" />
                                </div>
                            </div>
                        )}
                        <div ref={messagesEndRef} />
                    </div>

                    {/* Input */}
                    <div className="p-3 border-t bg-white">
                        <div className="flex gap-2">
                            <input
                                type="text"
                                value={input}
                                onChange={(e) => setInput(e.target.value)}
                                onKeyPress={handleKeyPress}
                                placeholder="Nhập tin nhắn..."
                                className="flex-1 px-4 py-2 border border-gray-200 rounded-full focus:outline-none focus:border-blue-500 focus:ring-1 focus:ring-blue-500"
                                disabled={isLoading}
                            />
                            <button
                                onClick={handleSend}
                                disabled={!input.trim() || isLoading}
                                className="w-10 h-10 bg-gradient-to-r from-blue-500 to-purple-600 rounded-full flex items-center justify-center text-white disabled:opacity-50 disabled:cursor-not-allowed hover:from-blue-600 hover:to-purple-700 transition-colors"
                            >
                                <Send className="w-5 h-5" />
                            </button>
                        </div>
                    </div>
                </div>
            )}
        </>
    )
}
