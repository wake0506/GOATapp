import 'dart:typed_data';
import 'dart:ui';

import 'exercise_metadata.dart';

enum MuscleBodyView { front, back }

class SvgMusclePath {
  const SvgMusclePath({
    required this.id,
    required this.muscleRegion,
    required this.view,
    required this.path,
    this.hitSlop = 0,
  });

  final String id;
  final MuscleRegion muscleRegion;
  final MuscleBodyView view;
  final Path path;
  final double hitSlop;
}

class MuscleRegionSvgMapping {
  const MuscleRegionSvgMapping({
    required this.muscleRegion,
    required this.frontPathIds,
    required this.backPathIds,
    required this.fallbackBodyPart,
  });

  final MuscleRegion muscleRegion;
  final List<String> frontPathIds;
  final List<String> backPathIds;
  final String fallbackBodyPart;

  MuscleBodyView get preferredView => backPathIds.length > frontPathIds.length
      ? MuscleBodyView.back
      : MuscleBodyView.front;
}

class MuscleSvgAsset {
  const MuscleSvgAsset._();

  static const Size viewBox = Size(320, 720);

  static final Path frontBody = _bodySilhouette();
  static final Path backBody = _bodySilhouette();

  static final List<Path> frontDetails = [
    _line((path) {
      path
        ..moveTo(137, 105)
        ..quadraticBezierTo(160, 120, 183, 105);
    }),
    _line((path) {
      path
        ..moveTo(160, 112)
        ..lineTo(160, 327);
    }),
    _line((path) {
      path
        ..moveTo(112, 327)
        ..quadraticBezierTo(160, 348, 208, 327);
    }),
    _line((path) {
      path
        ..moveTo(110, 489)
        ..quadraticBezierTo(132, 499, 153, 488);
    }),
    _line((path) {
      path
        ..moveTo(167, 488)
        ..quadraticBezierTo(189, 499, 210, 489);
    }),
  ];

  static final List<Path> backDetails = [
    _line((path) {
      path
        ..moveTo(160, 98)
        ..lineTo(160, 327);
    }),
    _line((path) {
      path
        ..moveTo(102, 167)
        ..quadraticBezierTo(160, 142, 218, 167);
    }),
    _line((path) {
      path
        ..moveTo(113, 322)
        ..quadraticBezierTo(160, 344, 207, 322);
    }),
    _line((path) {
      path
        ..moveTo(111, 500)
        ..quadraticBezierTo(132, 510, 153, 499);
    }),
    _line((path) {
      path
        ..moveTo(167, 499)
        ..quadraticBezierTo(189, 510, 210, 500);
    }),
  ];

  static final List<SvgMusclePath> frontPaths = [
    ..._pair(
      id: 'front.upperChest',
      region: MuscleRegion.upperChest,
      view: MuscleBodyView.front,
      left: _shape((path) {
        path
          ..moveTo(118, 124)
          ..cubicTo(128, 113, 145, 111, 158, 121)
          ..lineTo(158, 143)
          ..cubicTo(143, 139, 129, 140, 114, 147)
          ..quadraticBezierTo(112, 133, 118, 124)
          ..close();
      }),
    ),
    ..._pair(
      id: 'front.midChest',
      region: MuscleRegion.midChest,
      view: MuscleBodyView.front,
      left: _shape((path) {
        path
          ..moveTo(113, 149)
          ..cubicTo(128, 142, 143, 142, 158, 146)
          ..lineTo(158, 181)
          ..cubicTo(144, 188, 125, 184, 111, 174)
          ..quadraticBezierTo(108, 160, 113, 149)
          ..close();
      }),
    ),
    ..._pair(
      id: 'front.lowerChest',
      region: MuscleRegion.lowerChest,
      view: MuscleBodyView.front,
      left: _shape((path) {
        path
          ..moveTo(112, 177)
          ..cubicTo(126, 186, 143, 190, 158, 184)
          ..lineTo(158, 204)
          ..cubicTo(143, 211, 126, 205, 116, 195)
          ..quadraticBezierTo(112, 187, 112, 177)
          ..close();
      }),
    ),
    ..._pair(
      id: 'front.frontDelts',
      region: MuscleRegion.frontDelts,
      view: MuscleBodyView.front,
      left: _shape((path) {
        path
          ..moveTo(92, 116)
          ..cubicTo(102, 106, 115, 108, 124, 120)
          ..cubicTo(119, 133, 113, 146, 101, 154)
          ..cubicTo(91, 147, 86, 129, 92, 116)
          ..close();
      }),
      hitSlop: 3,
    ),
    ..._pair(
      id: 'front.sideDelts',
      region: MuscleRegion.sideDelts,
      view: MuscleBodyView.front,
      left: _shape((path) {
        path
          ..moveTo(78, 127)
          ..cubicTo(82, 115, 92, 111, 101, 115)
          ..cubicTo(91, 127, 89, 145, 95, 158)
          ..cubicTo(84, 160, 76, 145, 78, 127)
          ..close();
      }),
      hitSlop: 4,
    ),
    ..._pair(
      id: 'front.biceps',
      region: MuscleRegion.biceps,
      view: MuscleBodyView.front,
      left: _shape((path) {
        path
          ..moveTo(75, 161)
          ..cubicTo(83, 153, 94, 157, 98, 169)
          ..cubicTo(96, 193, 90, 220, 78, 238)
          ..cubicTo(67, 222, 66, 181, 75, 161)
          ..close();
      }),
    ),
    ..._pair(
      id: 'front.forearms',
      region: MuscleRegion.forearms,
      view: MuscleBodyView.front,
      left: _shape((path) {
        path
          ..moveTo(68, 234)
          ..cubicTo(78, 228, 87, 234, 89, 247)
          ..cubicTo(85, 276, 77, 307, 65, 329)
          ..cubicTo(55, 312, 56, 264, 68, 234)
          ..close();
      }),
      hitSlop: 3,
    ),
    ..._pair(
      id: 'front.obliques',
      region: MuscleRegion.obliques,
      view: MuscleBodyView.front,
      left: _shape((path) {
        path
          ..moveTo(111, 205)
          ..cubicTo(120, 212, 128, 218, 135, 221)
          ..cubicTo(132, 246, 132, 276, 138, 301)
          ..cubicTo(125, 296, 116, 286, 109, 270)
          ..cubicTo(104, 244, 105, 221, 111, 205)
          ..close();
      }),
    ),
    ..._pair(
      id: 'front.abs.upper',
      region: MuscleRegion.abs,
      view: MuscleBodyView.front,
      left: _shape((path) {
        path
          ..moveTo(138, 211)
          ..quadraticBezierTo(148, 207, 158, 211)
          ..lineTo(158, 236)
          ..quadraticBezierTo(148, 241, 137, 236)
          ..close();
      }),
    ),
    ..._pair(
      id: 'front.abs.middle',
      region: MuscleRegion.abs,
      view: MuscleBodyView.front,
      left: _shape((path) {
        path
          ..moveTo(137, 240)
          ..quadraticBezierTo(148, 244, 158, 240)
          ..lineTo(158, 267)
          ..quadraticBezierTo(148, 272, 137, 267)
          ..close();
      }),
    ),
    ..._pair(
      id: 'front.abs.lower',
      region: MuscleRegion.abs,
      view: MuscleBodyView.front,
      left: _shape((path) {
        path
          ..moveTo(138, 271)
          ..quadraticBezierTo(148, 275, 158, 271)
          ..lineTo(158, 304)
          ..quadraticBezierTo(148, 306, 141, 298)
          ..close();
      }),
    ),
    ..._pair(
      id: 'front.quads',
      region: MuscleRegion.quads,
      view: MuscleBodyView.front,
      left: _shape((path) {
        path
          ..moveTo(116, 352)
          ..cubicTo(127, 342, 145, 345, 154, 358)
          ..cubicTo(154, 392, 151, 441, 144, 486)
          ..cubicTo(133, 497, 117, 492, 109, 480)
          ..cubicTo(104, 432, 105, 382, 116, 352)
          ..close();
      }),
    ),
    ..._pair(
      id: 'front.adductors',
      region: MuscleRegion.adductors,
      view: MuscleBodyView.front,
      left: _shape((path) {
        path
          ..moveTo(144, 348)
          ..quadraticBezierTo(154, 345, 158, 354)
          ..lineTo(158, 456)
          ..quadraticBezierTo(151, 474, 144, 482)
          ..cubicTo(148, 427, 148, 382, 144, 348)
          ..close();
      }),
      hitSlop: 3,
    ),
    ..._pair(
      id: 'front.calves',
      region: MuscleRegion.calves,
      view: MuscleBodyView.front,
      left: _shape((path) {
        path
          ..moveTo(113, 510)
          ..cubicTo(126, 500, 140, 508, 146, 523)
          ..cubicTo(144, 560, 139, 608, 130, 641)
          ..cubicTo(118, 637, 111, 622, 108, 601)
          ..cubicTo(105, 565, 106, 531, 113, 510)
          ..close();
      }),
      hitSlop: 3,
    ),
  ];

  static final List<SvgMusclePath> backPaths = [
    ..._pair(
      id: 'back.rearDelts',
      region: MuscleRegion.rearDelts,
      view: MuscleBodyView.back,
      left: _shape((path) {
        path
          ..moveTo(83, 124)
          ..cubicTo(88, 110, 103, 106, 117, 116)
          ..cubicTo(116, 135, 108, 151, 96, 160)
          ..cubicTo(83, 155, 77, 139, 83, 124)
          ..close();
      }),
      hitSlop: 4,
    ),
    ..._pair(
      id: 'back.upperBack',
      region: MuscleRegion.upperBack,
      view: MuscleBodyView.back,
      left: _shape((path) {
        path
          ..moveTo(145, 104)
          ..cubicTo(151, 110, 156, 114, 158, 118)
          ..lineTo(158, 170)
          ..cubicTo(143, 165, 129, 154, 116, 142)
          ..cubicTo(111, 134, 112, 124, 119, 117)
          ..quadraticBezierTo(133, 112, 145, 104)
          ..close();
      }),
    ),
    ..._pair(
      id: 'back.lats',
      region: MuscleRegion.lats,
      view: MuscleBodyView.back,
      left: _shape((path) {
        path
          ..moveTo(108, 161)
          ..cubicTo(119, 160, 130, 169, 138, 181)
          ..cubicTo(136, 215, 133, 254, 119, 289)
          ..cubicTo(107, 281, 100, 263, 97, 240)
          ..cubicTo(97, 207, 99, 180, 108, 161)
          ..close();
      }),
    ),
    ..._pair(
      id: 'back.midBack',
      region: MuscleRegion.midBack,
      view: MuscleBodyView.back,
      left: _shape((path) {
        path
          ..moveTo(139, 169)
          ..quadraticBezierTo(148, 166, 158, 173)
          ..lineTo(158, 245)
          ..cubicTo(149, 248, 141, 242, 134, 233)
          ..cubicTo(137, 210, 138, 188, 139, 169)
          ..close();
      }),
    ),
    ..._pair(
      id: 'back.lowerBack',
      region: MuscleRegion.lowerBack,
      view: MuscleBodyView.back,
      left: _shape((path) {
        path
          ..moveTo(132, 246)
          ..quadraticBezierTo(145, 252, 158, 248)
          ..lineTo(158, 322)
          ..quadraticBezierTo(143, 326, 119, 315)
          ..cubicTo(122, 287, 125, 263, 132, 246)
          ..close();
      }),
    ),
    ..._pair(
      id: 'back.spinalErectors',
      region: MuscleRegion.spinalErectors,
      view: MuscleBodyView.back,
      left: _shape((path) {
        path
          ..moveTo(148, 170)
          ..quadraticBezierTo(153, 166, 158, 171)
          ..lineTo(158, 319)
          ..quadraticBezierTo(153, 321, 148, 317)
          ..cubicTo(145, 268, 145, 216, 148, 170)
          ..close();
      }),
      hitSlop: 2,
    ),
    ..._pair(
      id: 'back.triceps',
      region: MuscleRegion.triceps,
      view: MuscleBodyView.back,
      left: _shape((path) {
        path
          ..moveTo(74, 161)
          ..cubicTo(84, 154, 94, 160, 98, 171)
          ..cubicTo(95, 198, 89, 223, 78, 240)
          ..cubicTo(68, 224, 66, 181, 74, 161)
          ..close();
      }),
    ),
    ..._pair(
      id: 'back.forearms',
      region: MuscleRegion.forearms,
      view: MuscleBodyView.back,
      left: _shape((path) {
        path
          ..moveTo(67, 236)
          ..cubicTo(78, 229, 87, 237, 89, 250)
          ..cubicTo(84, 282, 76, 310, 64, 330)
          ..cubicTo(55, 310, 57, 264, 67, 236)
          ..close();
      }),
      hitSlop: 3,
    ),
    ..._pair(
      id: 'back.glutes',
      region: MuscleRegion.glutes,
      view: MuscleBodyView.back,
      left: _shape((path) {
        path
          ..moveTo(113, 327)
          ..cubicTo(126, 320, 144, 322, 158, 332)
          ..lineTo(158, 388)
          ..cubicTo(143, 399, 122, 394, 109, 382)
          ..quadraticBezierTo(105, 348, 113, 327)
          ..close();
      }),
    ),
    ..._pair(
      id: 'back.hamstrings',
      region: MuscleRegion.hamstrings,
      view: MuscleBodyView.back,
      left: _shape((path) {
        path
          ..moveTo(112, 391)
          ..cubicTo(126, 399, 141, 400, 154, 391)
          ..cubicTo(153, 429, 149, 475, 143, 507)
          ..cubicTo(130, 515, 116, 507, 108, 493)
          ..cubicTo(103, 454, 105, 416, 112, 391)
          ..close();
      }),
    ),
    ..._pair(
      id: 'back.calves',
      region: MuscleRegion.calves,
      view: MuscleBodyView.back,
      left: _shape((path) {
        path
          ..moveTo(113, 515)
          ..cubicTo(127, 502, 142, 511, 147, 529)
          ..cubicTo(145, 570, 139, 612, 129, 642)
          ..cubicTo(117, 636, 109, 620, 107, 599)
          ..cubicTo(105, 562, 106, 533, 113, 515)
          ..close();
      }),
      hitSlop: 3,
    ),
  ];

  static List<SvgMusclePath> pathsFor(MuscleBodyView view) =>
      view == MuscleBodyView.front ? frontPaths : backPaths;

  static Path bodyFor(MuscleBodyView view) =>
      view == MuscleBodyView.front ? frontBody : backBody;

  static List<Path> detailsFor(MuscleBodyView view) =>
      view == MuscleBodyView.front ? frontDetails : backDetails;
}

final Map<MuscleRegion, MuscleRegionSvgMapping> muscleRegionSvgMapping = {
  MuscleRegion.upperChest: const MuscleRegionSvgMapping(
    muscleRegion: MuscleRegion.upperChest,
    frontPathIds: ['front.upperChest.left', 'front.upperChest.right'],
    backPathIds: [],
    fallbackBodyPart: '胸部',
  ),
  MuscleRegion.midChest: const MuscleRegionSvgMapping(
    muscleRegion: MuscleRegion.midChest,
    frontPathIds: ['front.midChest.left', 'front.midChest.right'],
    backPathIds: [],
    fallbackBodyPart: '胸部',
  ),
  MuscleRegion.lowerChest: const MuscleRegionSvgMapping(
    muscleRegion: MuscleRegion.lowerChest,
    frontPathIds: ['front.lowerChest.left', 'front.lowerChest.right'],
    backPathIds: [],
    fallbackBodyPart: '胸部',
  ),
  MuscleRegion.lats: const MuscleRegionSvgMapping(
    muscleRegion: MuscleRegion.lats,
    frontPathIds: [],
    backPathIds: ['back.lats.left', 'back.lats.right'],
    fallbackBodyPart: '背部',
  ),
  MuscleRegion.upperBack: const MuscleRegionSvgMapping(
    muscleRegion: MuscleRegion.upperBack,
    frontPathIds: [],
    backPathIds: ['back.upperBack.left', 'back.upperBack.right'],
    fallbackBodyPart: '背部',
  ),
  MuscleRegion.midBack: const MuscleRegionSvgMapping(
    muscleRegion: MuscleRegion.midBack,
    frontPathIds: [],
    backPathIds: ['back.midBack.left', 'back.midBack.right'],
    fallbackBodyPart: '背部',
  ),
  MuscleRegion.lowerBack: const MuscleRegionSvgMapping(
    muscleRegion: MuscleRegion.lowerBack,
    frontPathIds: [],
    backPathIds: ['back.lowerBack.left', 'back.lowerBack.right'],
    fallbackBodyPart: '背部',
  ),
  MuscleRegion.frontDelts: const MuscleRegionSvgMapping(
    muscleRegion: MuscleRegion.frontDelts,
    frontPathIds: ['front.frontDelts.left', 'front.frontDelts.right'],
    backPathIds: [],
    fallbackBodyPart: '肩部',
  ),
  MuscleRegion.sideDelts: const MuscleRegionSvgMapping(
    muscleRegion: MuscleRegion.sideDelts,
    frontPathIds: ['front.sideDelts.left', 'front.sideDelts.right'],
    backPathIds: [],
    fallbackBodyPart: '肩部',
  ),
  MuscleRegion.rearDelts: const MuscleRegionSvgMapping(
    muscleRegion: MuscleRegion.rearDelts,
    frontPathIds: [],
    backPathIds: ['back.rearDelts.left', 'back.rearDelts.right'],
    fallbackBodyPart: '肩部',
  ),
  MuscleRegion.biceps: const MuscleRegionSvgMapping(
    muscleRegion: MuscleRegion.biceps,
    frontPathIds: ['front.biceps.left', 'front.biceps.right'],
    backPathIds: [],
    fallbackBodyPart: '手臂',
  ),
  MuscleRegion.triceps: const MuscleRegionSvgMapping(
    muscleRegion: MuscleRegion.triceps,
    frontPathIds: [],
    backPathIds: ['back.triceps.left', 'back.triceps.right'],
    fallbackBodyPart: '手臂',
  ),
  MuscleRegion.forearms: const MuscleRegionSvgMapping(
    muscleRegion: MuscleRegion.forearms,
    frontPathIds: ['front.forearms.left', 'front.forearms.right'],
    backPathIds: ['back.forearms.left', 'back.forearms.right'],
    fallbackBodyPart: '手臂',
  ),
  MuscleRegion.quads: const MuscleRegionSvgMapping(
    muscleRegion: MuscleRegion.quads,
    frontPathIds: ['front.quads.left', 'front.quads.right'],
    backPathIds: [],
    fallbackBodyPart: '腿部',
  ),
  MuscleRegion.hamstrings: const MuscleRegionSvgMapping(
    muscleRegion: MuscleRegion.hamstrings,
    frontPathIds: [],
    backPathIds: ['back.hamstrings.left', 'back.hamstrings.right'],
    fallbackBodyPart: '腿部',
  ),
  MuscleRegion.calves: const MuscleRegionSvgMapping(
    muscleRegion: MuscleRegion.calves,
    frontPathIds: ['front.calves.left', 'front.calves.right'],
    backPathIds: ['back.calves.left', 'back.calves.right'],
    fallbackBodyPart: '腿部',
  ),
  MuscleRegion.adductors: const MuscleRegionSvgMapping(
    muscleRegion: MuscleRegion.adductors,
    frontPathIds: ['front.adductors.left', 'front.adductors.right'],
    backPathIds: [],
    fallbackBodyPart: '腿部',
  ),
  MuscleRegion.glutes: const MuscleRegionSvgMapping(
    muscleRegion: MuscleRegion.glutes,
    frontPathIds: [],
    backPathIds: ['back.glutes.left', 'back.glutes.right'],
    fallbackBodyPart: '臀部',
  ),
  MuscleRegion.abs: const MuscleRegionSvgMapping(
    muscleRegion: MuscleRegion.abs,
    frontPathIds: [
      'front.abs.upper.left',
      'front.abs.upper.right',
      'front.abs.middle.left',
      'front.abs.middle.right',
      'front.abs.lower.left',
      'front.abs.lower.right',
    ],
    backPathIds: [],
    fallbackBodyPart: '核心',
  ),
  MuscleRegion.obliques: const MuscleRegionSvgMapping(
    muscleRegion: MuscleRegion.obliques,
    frontPathIds: ['front.obliques.left', 'front.obliques.right'],
    backPathIds: [],
    fallbackBodyPart: '核心',
  ),
  MuscleRegion.spinalErectors: const MuscleRegionSvgMapping(
    muscleRegion: MuscleRegion.spinalErectors,
    frontPathIds: [],
    backPathIds: ['back.spinalErectors.left', 'back.spinalErectors.right'],
    fallbackBodyPart: '核心',
  ),
};

final List<MuscleRegion> unmappedMuscleRegionsSvg = MuscleRegion.values
    .where((region) => !muscleRegionSvgMapping.containsKey(region))
    .toList(growable: false);

Path _bodySilhouette() => _shape((path) {
  path
    ..moveTo(160, 8)
    ..cubicTo(181, 8, 192, 26, 190, 49)
    ..cubicTo(189, 69, 181, 83, 175, 89)
    ..lineTo(177, 100)
    ..cubicTo(190, 104, 207, 106, 223, 112)
    ..cubicTo(240, 118, 247, 133, 246, 151)
    ..cubicTo(251, 180, 258, 214, 264, 252)
    ..cubicTo(270, 286, 269, 316, 258, 337)
    ..cubicTo(252, 348, 242, 347, 237, 336)
    ..cubicTo(236, 304, 231, 270, 224, 237)
    ..cubicTo(221, 219, 217, 201, 212, 183)
    ..cubicTo(211, 225, 213, 273, 207, 315)
    ..cubicTo(211, 330, 216, 342, 218, 357)
    ..cubicTo(219, 403, 214, 453, 210, 496)
    ..cubicTo(216, 530, 214, 573, 211, 610)
    ..lineTo(208, 674)
    ..cubicTo(215, 686, 213, 700, 202, 706)
    ..lineTo(174, 706)
    ..cubicTo(168, 699, 168, 688, 174, 677)
    ..cubicTo(171, 628, 168, 579, 166, 531)
    ..cubicTo(164, 489, 164, 445, 166, 404)
    ..cubicTo(166, 387, 164, 372, 160, 359)
    ..cubicTo(156, 372, 154, 387, 154, 404)
    ..cubicTo(156, 445, 156, 489, 154, 531)
    ..cubicTo(152, 579, 149, 628, 146, 677)
    ..cubicTo(152, 688, 152, 699, 146, 706)
    ..lineTo(118, 706)
    ..cubicTo(107, 700, 105, 686, 112, 674)
    ..lineTo(109, 610)
    ..cubicTo(106, 573, 104, 530, 110, 496)
    ..cubicTo(106, 453, 101, 403, 102, 357)
    ..cubicTo(104, 342, 109, 330, 113, 315)
    ..cubicTo(107, 273, 109, 225, 108, 183)
    ..cubicTo(103, 201, 99, 219, 96, 237)
    ..cubicTo(89, 270, 84, 304, 83, 336)
    ..cubicTo(78, 347, 68, 348, 62, 337)
    ..cubicTo(51, 316, 50, 286, 56, 252)
    ..cubicTo(62, 214, 69, 180, 74, 151)
    ..cubicTo(73, 133, 80, 118, 97, 112)
    ..cubicTo(113, 106, 130, 104, 143, 100)
    ..lineTo(145, 89)
    ..cubicTo(139, 83, 131, 69, 130, 49)
    ..cubicTo(128, 26, 139, 8, 160, 8)
    ..close();
});

List<SvgMusclePath> _pair({
  required String id,
  required MuscleRegion region,
  required MuscleBodyView view,
  required Path left,
  double hitSlop = 0,
}) => [
  SvgMusclePath(
    id: '$id.left',
    muscleRegion: region,
    view: view,
    path: left,
    hitSlop: hitSlop,
  ),
  SvgMusclePath(
    id: '$id.right',
    muscleRegion: region,
    view: view,
    path: _mirror(left),
    hitSlop: hitSlop,
  ),
];

Path _shape(void Function(Path path) draw) {
  final path = Path();
  draw(path);
  return _expandX(path);
}

Path _line(void Function(Path path) draw) {
  final path = Path();
  draw(path);
  return _expandX(path);
}

Path _expandX(Path path) => path.transform(
  Float64List.fromList([1.16, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, -25.6, 0, 0, 1]),
);

Path _mirror(Path path) => path.transform(
  Float64List.fromList([-1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 320, 0, 0, 1]),
);
