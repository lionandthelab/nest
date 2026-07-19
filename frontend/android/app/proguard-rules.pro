# okhttp3가 선택적으로 참조하는 TLS 구현체들 — 앱에 포함하지 않으므로
# R8 누락 클래스 경고만 억제한다 (릴리스 minify 실패 방지).
-dontwarn org.conscrypt.**
-dontwarn org.openjsse.**
-dontwarn org.bouncycastle.jsse.**
