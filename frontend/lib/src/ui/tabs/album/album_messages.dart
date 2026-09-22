import '../../../services/album_organizer.dart';

/// 내려받기 결과를 사용자 문구로 옮긴다.
///
/// 플랫폼마다 할 수 있는 일이 달라, "저장했습니다"와 "새 창에서 열었습니다"와
/// "이 기기에서는 안 됩니다"가 전부 다른 이야기다. 한곳에 모아 둔다.
String albumDownloadMessage(AlbumDownloadOutcome outcome) {
  return switch (outcome) {
    AlbumDownloadOutcome.savedSingle => '사진을 저장했습니다.',
    AlbumDownloadOutcome.savedZip => 'zip 파일로 저장했습니다.',
    AlbumDownloadOutcome.openedExternally =>
      '사진을 새 창에서 열었습니다. 길게 눌러 저장하세요.',
    AlbumDownloadOutcome.bulkUnsupported =>
      '이 기기에서는 여러 장을 한 번에 저장할 수 없습니다. 웹(브라우저)에서 앨범을 열어 내려받아 주세요.',
    AlbumDownloadOutcome.tooLarge =>
      '한 번에 300MB까지 내려받을 수 있습니다. 나눠서 선택해 주세요.',
    AlbumDownloadOutcome.empty => '내려받을 사진을 먼저 선택하세요.',
    AlbumDownloadOutcome.failed => '사진을 내려받지 못했습니다.',
  };
}
