// API 테스트 스크립트
const https = require('https');

// propose101@gmail.com 계정으로 로그인 (테스트용)
const loginData = JSON.stringify({
  email: 'propose101@gmail.com',
  password: 'your-password-here'  // 실제 비밀번호로 변경 필요
});

const loginOptions = {
  hostname: 'in-sign.shop',
  port: 443,
  path: '/api/auth/login',
  method: 'POST',
  headers: {
    'Content-Type': 'application/json',
    'Content-Length': loginData.length
  }
};

console.log('🔐 로그인 시도...');

const req = https.request(loginOptions, (res) => {
  let data = '';

  res.on('data', (chunk) => {
    data += chunk;
  });

  res.on('end', () => {
    if (res.statusCode === 200) {
      const response = JSON.parse(data);
      const token = response.accessToken;
      console.log('✅ 로그인 성공!');
      console.log('Token:', token.substring(0, 20) + '...');

      // 출석 히스토리 조회
      const historyOptions = {
        hostname: 'in-sign.shop',
        port: 443,
        path: '/api/auth/check-in-history?year=2025&month=11',
        method: 'GET',
        headers: {
          'Authorization': `Bearer ${token}`
        }
      };

      console.log('\n📅 출석 히스토리 조회...');

      const historyReq = https.request(historyOptions, (historyRes) => {
        let historyData = '';

        historyRes.on('data', (chunk) => {
          historyData += chunk;
        });

        historyRes.on('end', () => {
          console.log('응답 상태:', historyRes.statusCode);
          console.log('응답 데이터:', historyData);

          if (historyRes.statusCode === 200) {
            const history = JSON.parse(historyData);
            console.log('\n✅ 출석 히스토리:', history.length, '개');
            history.forEach((date, i) => {
              console.log(`  ${i + 1}. ${date}`);
            });
          }
        });
      });

      historyReq.on('error', (e) => {
        console.error('❌ 히스토리 조회 에러:', e.message);
      });

      historyReq.end();
    } else {
      console.error('❌ 로그인 실패:', res.statusCode);
      console.error(data);
    }
  });
});

req.on('error', (e) => {
  console.error('❌ 로그인 에러:', e.message);
});

req.write(loginData);
req.end();
