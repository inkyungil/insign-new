-- 이벤트 테이블 생성
CREATE TABLE IF NOT EXISTS events (
  id INT PRIMARY KEY AUTO_INCREMENT,
  title VARCHAR(255) NOT NULL COMMENT '이벤트 제목',
  content TEXT NOT NULL COMMENT '이벤트 내용',
  start_date DATE NULL COMMENT '시작일',
  end_date DATE NULL COMMENT '종료일',
  is_active TINYINT(1) NOT NULL DEFAULT 1 COMMENT '활성화 여부',
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP COMMENT '생성일',
  updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '수정일'
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='이벤트 관리';

-- 샘플 데이터 추가
INSERT INTO events (title, content, start_date, end_date, is_active) VALUES
('서비스 오픈 기념 이벤트', '인싸인 서비스 오픈을 기념하여 모든 사용자에게 포인트 10개를 지급합니다!', '2024-12-01', '2024-12-31', 1),
('연말 감사 이벤트', '연말을 맞아 프리미엄 플랜을 특별 할인가로 제공합니다.', '2024-12-20', '2024-12-31', 1);
