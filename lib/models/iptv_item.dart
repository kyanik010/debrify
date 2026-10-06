class IptvItem {
  const IptvItem({required this.name, required this.url, this.logo, this.group, this.kind=IptvKind.live, this.id, this.season, this.episode, this.headers=const {}});
  final String name, url;
  final String? logo, group, id;
  final IptvKind kind;
  final int? season, episode;
  final Map<String,String> headers;
}
enum IptvKind { live, movie, series }
