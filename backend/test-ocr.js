// Test OCR với một ảnh mẫu
const { analyzeReceipt } = require('./src/services/gemini.service');
const fs = require('fs');

// Tạo một ảnh test đơn giản (1x1 pixel PNG)
const testImageBase64 = 'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==';

async function test() {
  console.log('🧪 Testing OCR service...\n');
  
  try {
    const result = await analyzeReceipt(testImageBase64, 'image/png');
    console.log('✅ Result:', JSON.stringify(result, null, 2));
  } catch (error) {
    console.error('❌ Error:', error.message);
    console.error(error);
  }
}

test();
