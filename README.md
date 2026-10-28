# 美談(미담) — 공개 글귀 아카이브

반응형 웹사이트 초기 구현입니다. 공개 열람, 장소/문장 검색, 상세 보기, 익명 댓글, 신고 접수, 관리자 로그인, 글귀 CRUD, 사진 업로드를 포함합니다.

## 기술 구성
- 정적 웹 프런트엔드: HTML/CSS/JavaScript
- 저장소/DB/인증: Supabase
- 배포: Vercel 또는 Netlify의 정적 사이트 배포

## 1. Supabase 프로젝트 준비
1. Supabase에서 새 프로젝트를 만듭니다.
2. `database/schema.sql` 전체를 SQL Editor에 붙여넣어 실행합니다.
3. Project Settings → API에서 Project URL과 `anon`/publishable public key를 복사합니다.
4. `index.html`의 `SUPABASE_URL`, `SUPABASE_ANON_KEY` 값을 바꿉니다. `service_role`/secret key는 절대로 브라우저 코드에 넣지 마세요.

## 2. 관리자 계정 설정
1. Supabase Authentication에서 관리자 사용자를 직접 생성하거나 초대합니다. 공개 회원가입은 열지 않는 것을 권장합니다.
2. 해당 사용자에게 신뢰할 수 있는 관리자 권한을 부여합니다. SQL Editor에서 사용자 UUID를 확인한 뒤, 프로젝트 소유자 권한으로 아래 SQL을 실행합니다.

```sql
update auth.users
set raw_app_meta_data = coalesce(raw_app_meta_data, '{}'::jsonb) || '{"role":"admin"}'::jsonb
where id = '여기에-관리자-사용자-UUID';
```

3. 관리자는 사이트 상단의 `관리자` 버튼으로 이메일/비밀번호 로그인합니다. 관리자 역할은 `app_metadata`에 있어야 하며 `user_metadata`에 넣으면 안 됩니다.

## 3. 배포
### Vercel
1. 이 폴더를 GitHub 저장소에 올립니다.
2. Vercel에서 해당 저장소를 Import합니다.
3. Framework Preset은 `Other`, Build Command는 비워두고, Output Directory는 `.`으로 설정합니다.
4. Output Directory는 `public`으로 설정한 뒤 Deploy를 누릅니다. 단일 정적 HTML 사이트라 별도 빌드가 필요하지 않습니다. `public/` 폴더에는 웹에서 공개할 파일만 두었으며, SQL 설정 파일은 배포 경로 밖에 둡니다.

또는 `public/` 폴더만 정적 호스팅 서비스에 배포하면 됩니다. `database/schema.sql`은 배포용 공개 경로에 포함하지 마세요. 루트 `index.html`은 로컬 미리보기용 사본입니다.

## 4. 운영 전 필수 점검
- [ ] 실제 프로젝트 URL/공개 키를 넣었는지 확인
- [ ] SQL을 실행했고 Storage bucket `quote-photos`가 만들어졌는지 확인
- [ ] 관리자 계정에 `app_metadata.role=admin`을 부여했는지 확인
- [ ] 비공개 글귀는 공개 사용자에게 노출되지 않는지 확인
- [ ] 사진 속 학생 얼굴, 이름, 학번, 시간표 등 개인정보를 검토했는지 확인
- [ ] 인용문 출처와 저작권을 확인했는지 확인
- [ ] 공개 댓글 서비스에 CAPTCHA 또는 rate limit을 추가했는지 확인
- [ ] 신고 댓글 확인·숨김 처리 절차를 운영자가 정했는지 확인
- [ ] 학교 담당자 승인과 개인정보 처리 안내를 준비했는지 확인

## 개인정보/운영 주의
이 버전의 댓글은 별도 계정 없이 작성할 수 있어 접근이 쉽지만, 스팸·도배를 완전히 막지는 못합니다. 학교에서 실제 공개 운영하기 전에 CAPTCHA/속도 제한을 추가하고, 운영자가 댓글을 숨기거나 삭제할 수 있는 절차를 확인하세요. 신고 접수는 구현되어 있지만 신고 관리 전용 화면은 아직 별도 구현이 필요합니다. 댓글을 숨기는 기능은 Supabase 대시보드의 `comments.status`를 `hidden`으로 바꾸면 됩니다.

사진 저장소는 공개 이미지 URL 방식입니다. 민감한 사진이나 학생 얼굴이 포함된 이미지는 올리지 마세요. 관리자는 업로드 전에 촬영 동의 및 학교 규정을 확인해야 합니다.

## 현재 미리보기 동작
Supabase 설정 전에도 페이지 디자인과 예시 글귀 3개를 볼 수 있습니다. 설정 전 댓글·글귀·사진은 서버에 저장되지 않으며, 미리보기 데이터는 예시일 뿐 실제 학교 기록이 아닙니다.


## Supabase 연결

이 버전의 HTML에는 프로젝트 URL과 publishable key가 입력되어 있습니다. 브라우저에 노출되어도 되는 publishable key만 사용하고, secret/service_role 키는 절대 넣지 마세요. 공개 전에는 RLS 정책과 Storage 정책을 점검하세요.
