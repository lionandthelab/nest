# fastlane 실행 전용 이미지(Flutter 미포함). AAB는 호스트에서 빌드하고,
# 업로드(supply)만 이 컨테이너에서 실행한다. 리포는 런타임에 볼륨 마운트.
FROM ruby:3.3
RUN gem install fastlane -N
WORKDIR /repo/frontend/android
