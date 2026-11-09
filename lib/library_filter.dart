enum PlaybackFilter {
  all('전체'),
  unplayed('미재생'),
  played('재생한 적 있음');

  final String label;
  const PlaybackFilter(this.label);
}

class LibraryFilter {
  final PlaybackFilter playback;
  final int? rating;
  final bool exact, unrated, actorsAll, tagsAll;
  final List<int> actorIds, tagIds;
  LibraryFilter({
    this.playback = PlaybackFilter.all,
    this.rating,
    this.exact = false,
    this.unrated = false,
    this.actorsAll = false,
    this.tagsAll = true,
    Iterable<int> actorIds = const [],
    Iterable<int> tagIds = const [],
  }) : actorIds = List.unmodifiable(actorIds.toSet()),
       tagIds = List.unmodifiable(tagIds.toSet()) {
    if (rating != null && (rating! < 1 || rating! > 5))
      throw ArgumentError('Rating must be 1–5');
    if (unrated && rating != null)
      throw ArgumentError('Unrated and rating are exclusive');
  }
  int get groupCount =>
      (playback != PlaybackFilter.all ? 1 : 0) +
      (rating != null || unrated ? 1 : 0) +
      (actorIds.isNotEmpty ? 1 : 0) +
      (tagIds.isNotEmpty ? 1 : 0);
  bool get isEmpty => groupCount == 0;
  String get ratingLabel => unrated
      ? '미평가'
      : rating == null
      ? '모든 평점'
      : '${'★' * rating!}${'☆' * (5 - rating!)} · $rating점 ${exact ? '정확히' : '이상'}';
  String get summary => [
    if (playback != PlaybackFilter.all) playback.label,
    if (rating != null || unrated) ratingLabel,
    if (actorIds.isNotEmpty)
      '배우 ${actorIds.length}명 · ${actorsAll ? '모두' : '하나라도'}',
    if (tagIds.isNotEmpty) '태그 ${tagIds.length}개 · ${tagsAll ? '모두' : '하나라도'}',
  ].join(' / ');
  LibraryFilter withoutRating() => LibraryFilter(
    playback: playback,
    actorIds: actorIds,
    tagIds: tagIds,
    actorsAll: actorsAll,
    tagsAll: tagsAll,
  );
  LibraryFilter withIds({Iterable<int>? actors, Iterable<int>? tags}) =>
      LibraryFilter(
        playback: playback,
        rating: rating,
        exact: exact,
        unrated: unrated,
        actorIds: actors ?? actorIds,
        tagIds: tags ?? tagIds,
        actorsAll: actorsAll,
        tagsAll: tagsAll,
      );
  Map<String, Object?> toJson() => {
    'playback': playback.name,
    'rating': rating,
    'exact': exact,
    'unrated': unrated,
    'actorIds': actorIds,
    'tagIds': tagIds,
    'actorsAll': actorsAll,
    'tagsAll': tagsAll,
  };
  factory LibraryFilter.fromJson(Map<String, dynamic> json) => LibraryFilter(
    playback:
        PlaybackFilter.values
            .where((value) => value.name == json['playback'])
            .firstOrNull ??
        PlaybackFilter.all,
    rating: json['unrated'] == true ? null : json['rating'] as int?,
    exact: json['exact'] == true,
    unrated: json['unrated'] == true,
    actorIds: (json['actorIds'] as List? ?? []).cast<int>(),
    tagIds: (json['tagIds'] as List? ?? []).cast<int>(),
    actorsAll: json['actorsAll'] == true,
    tagsAll: json['tagsAll'] != false,
  );
  List<String> get clauses => [
    if (playback != PlaybackFilter.all)
      '${playback == PlaybackFilter.unplayed ? 'NOT ' : ''}(play_count > 0 OR last_played > 0 OR resume_ms > 0 OR watched = 1)',
    if (unrated) 'rating IS NULL',
    if (rating != null) 'rating ${exact ? '=' : '>='} ?',
    if (actorIds.isNotEmpty)
      _relation('actors', 'actor_id', actorIds, actorsAll),
    if (tagIds.isNotEmpty) _relation('tags', 'tag_id', tagIds, tagsAll),
  ];
  LibraryFilter withPlayback(PlaybackFilter value) => LibraryFilter(
    playback: value,
    rating: rating,
    exact: exact,
    unrated: unrated,
    actorIds: actorIds,
    tagIds: tagIds,
    actorsAll: actorsAll,
    tagsAll: tagsAll,
  );
  String _relation(String table, String field, List<int> ids, bool all) {
    final marks = List.filled(ids.length, '?').join(',');
    return all
        ? '(SELECT COUNT(DISTINCT r.$field) FROM media_$table r WHERE r.media_id=media.id AND r.$field IN ($marks)) = ${ids.length}'
        : 'EXISTS (SELECT 1 FROM media_$table r WHERE r.media_id=media.id AND r.$field IN ($marks))';
  }

  List<Object?> get arguments => [
    if (rating != null) rating,
    ...actorIds,
    ...tagIds,
  ];
}
