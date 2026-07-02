import 'package:flutter_test/flutter_test.dart';
import 'package:rabbit/models/post.dart';
import 'package:rabbit/services/tagger.dart';
import 'package:rabbit/utils/format.dart';

Post makePost({String title = 'hello', String selftext = '', bool over18 = false}) {
  return Post.fromJson({
    'id': 'abc123',
    'name': 't3_abc123',
    'title': title,
    'author': 'someone',
    'subreddit': 'test',
    'created_utc': 1700000000,
    'score': 1234,
    'upvote_ratio': 0.97,
    'num_comments': 56,
    'selftext': selftext,
    'url': 'https://example.com/x.jpg',
    'domain': 'example.com',
    'permalink': '/r/test/comments/abc123/hello/',
    'thumbnail': 'self',
    'is_self': false,
    'over_18': over18,
    'spoiler': false,
    'stickied': false,
    'locked': false,
    'archived': false,
    'edited': false,
    'is_video': false,
  });
}

void main() {
  group('Post.fromJson', () {
    test('parses core fields and upvote ratio', () {
      final p = makePost();
      expect(p.fullname, 't3_abc123');
      expect(p.upvoteRatio, 0.97);
      expect(p.score, 1234);
      expect(p.thumbnailUrl, isNull); // "self" is not a real thumbnail
      expect(p.isImage, isTrue);
    });
  });

  group('Tagger', () {
    test('flags heavy content from title keywords', () {
      final tags = Tagger.tag(makePost(title: 'Local man killed in crash'));
      expect(tags, contains(Tagger.heavy));
    });

    test('flags NSFW from the over_18 flag', () {
      final tags = Tagger.tag(makePost(over18: true));
      expect(tags.first, Tagger.nsfw);
    });

    test('does not false-positive on neutral titles', () {
      final tags = Tagger.tag(makePost(title: 'My new keyboard build'));
      expect(tags, isEmpty);
    });

    test('word boundaries prevent substring matches', () {
      // "warm" contains "war"; "skilled" contains "kill".
      final tags = Tagger.tag(makePost(title: 'A warm welcome for skilled bakers'));
      expect(tags, isNot(contains(Tagger.heavy)));
    });

    test('flags uplifting content', () {
      final tags = Tagger.tag(makePost(title: 'Shelter dog finally adopted after 3 years'));
      expect(tags, contains(Tagger.uplifting));
    });
  });

  group('format', () {
    test('compactCount', () {
      expect(compactCount(999), '999');
      expect(compactCount(1200), '1.2k');
      expect(compactCount(12345), '12k');
      expect(compactCount(2500000), '2.5m');
      expect(compactCount(-1200), '-1.2k');
    });

    test('formatDuration', () {
      expect(formatDuration(const Duration(seconds: 65)), '1:05');
      expect(formatDuration(const Duration(minutes: 9, seconds: 3)), '9:03');
    });
  });
}
