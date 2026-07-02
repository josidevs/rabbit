import 'package:flutter/material.dart';

import '../models/post.dart';

/// A heuristic content tag. Colors come from the Okabe–Ito colorblind-safe
/// palette and every tag carries an icon, so hue is never the only signal.
class PostTag {
  final String label;
  final IconData icon;
  final Color color;
  final Color onColor;
  const PostTag(this.label, this.icon, this.color,
      {this.onColor = Colors.white});
}

class _Rule {
  final PostTag tag;
  final RegExp pattern;
  _Rule(this.tag, List<String> words)
      : pattern = RegExp(
          r'\b(?:' + words.join('|') + r')\b',
          caseSensitive: false,
        );
}

/// Keyword/flag heuristics that warn about content before you tap it —
/// especially "gotcha" posts that read neutral in the title but carry
/// heavy or bait content.
class Tagger {
  // Okabe–Ito palette.
  static const _vermillion = Color(0xFFD55E00);
  static const _orange = Color(0xFFE69F00);
  static const _skyBlue = Color(0xFF56B4E9);
  static const _blue = Color(0xFF0072B2);
  static const _bluishGreen = Color(0xFF009E73);
  static const _reddishPurple = Color(0xFFCC79A7);
  static const _yellow = Color(0xFFF0E442);

  static const heavy = PostTag('Heavy', Icons.warning_amber_rounded, _vermillion);
  static const drama = PostTag('Drama', Icons.local_fire_department_outlined, _orange,
      onColor: Colors.black);
  static const politics = PostTag('Politics', Icons.account_balance_outlined, _blue);
  static const medical = PostTag('Medical', Icons.medical_services_outlined, _skyBlue,
      onColor: Colors.black);
  static const money = PostTag('Money/Scam?', Icons.attach_money_rounded, _yellow,
      onColor: Colors.black);
  static const uplifting = PostTag('Uplifting', Icons.sentiment_satisfied_alt_outlined,
      _bluishGreen);
  static const nsfw = PostTag('NSFW', Icons.explicit_outlined, _vermillion);
  static const spoilerTag = PostTag('Spoiler', Icons.visibility_off_outlined,
      _reddishPurple);

  static final List<_Rule> _rules = [
    _Rule(heavy, [
      'death', 'dead', 'die[ds]?', 'dying', 'kill(?:ed|ing|s)?', 'murder(?:ed|s)?',
      'suicide', 'suicidal', 'overdose', 'shooting', 'shot', 'stabb(?:ed|ing)',
      'war', 'bombing', 'massacre', 'genocide', 'abuse[dr]?', 'assault(?:ed)?',
      'rape[dr]?', 'kidnapp(?:ed|ing)', 'missing child', 'fatal(?:ly)?',
      'tragedy', 'tragic', 'grief', 'grieving', 'funeral', 'terminal',
      'crash(?:ed|es)?', 'wildfire', 'earthquake', 'hurricane', 'flood(?:ing|s)?',
      'passed away', 'r\\.?i\\.?p', 'obituary', 'euthan\\w+', 'put down',
    ]),
    _Rule(drama, [
      'aita', 'aitah', 'am i the asshole', 'drama', 'fired', 'quit(?:ting)?',
      'banned', 'lawsuit', 'su(?:e[ds]?|ing)', 'divorce[d]?', 'cheat(?:ed|ing|er)',
      'outrage[d]?', 'boycott(?:ing)?', 'scandal', 'controversy', 'backlash',
      'called out', 'exposed', 'meltdown', 'furious', 'slam(?:med|s)',
      'destroy(?:ed|s)', 'ruined', 'betrayed', 'toxic', 'entitled', 'karen',
    ]),
    _Rule(politics, [
      'politic\\w*', 'election', 'senate', 'senator', 'congress', 'parliament',
      'president(?:ial)?', 'prime minister', 'democrat[s]?', 'republican[s]?',
      'liberal[s]?', 'conservative[s]?', 'left[- ]wing', 'right[- ]wing',
      'tariff[s]?', 'sanction[s]?', 'legislation', 'supreme court', 'ballot',
      'immigration', 'protest(?:ers|s)?', 'white house', 'governor', 'campaign',
    ]),
    _Rule(medical, [
      'cancer', 'tumou?r', 'diagnos\\w+', 'chemo(?:therapy)?', 'surgery',
      'hospital(?:ized)?', 'icu', 'stroke', 'heart attack', 'dementia',
      'alzheimer\\w*', 'chronic', 'disease', 'epidemic', 'pandemic', 'outbreak',
      'infection', 'virus', 'measles', 'vaccin\\w+',
    ]),
    _Rule(money, [
      'scam(?:med|mer)?', 'crypto(?:currency)?', 'bitcoin', 'nft', 'giveaway',
      'get rich', 'passive income', 'pyramid scheme', 'mlm', 'ponzi',
      'guaranteed returns', 'airdrop', 'debt', 'bankrupt(?:cy)?', 'foreclosure',
      'evict(?:ed|ion)', 'layoff[s]?', 'laid off',
    ]),
    _Rule(uplifting, [
      'wholesome', 'good news', 'heartwarming', 'rescued', 'adopt(?:ed|s)',
      'reunited', 'recovered', 'in remission', 'cancer[- ]free', 'graduated',
      'first job', 'sober', 'milestone', 'random act of kindness', 'donated',
      'volunteer(?:ed|s)?', 'saved (?:a|the|his|her|their)',
    ]),
  ];

  /// Tags for a post, most important first. Flag-based tags (NSFW, Spoiler)
  /// always come before keyword heuristics.
  static List<PostTag> tag(Post post) {
    final tags = <PostTag>[];
    if (post.over18) tags.add(nsfw);
    if (post.spoiler) tags.add(spoilerTag);

    final text = '${post.title}\n${post.linkFlairText ?? ''}\n'
        '${post.selftext.length > 600 ? post.selftext.substring(0, 600) : post.selftext}';
    for (final rule in _rules) {
      if (rule.pattern.hasMatch(text)) tags.add(rule.tag);
    }
    // "Uplifting" next to "Heavy" usually means a hard story with a good
    // ending; keep both — the pairing itself is informative.
    return tags;
  }
}
