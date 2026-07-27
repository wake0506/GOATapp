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

  static final Path frontHead = _frontHead();
  static final Path backHead = _backHead();
  static final List<Path> frontCoreSurfaceParts = _frontSurfaceParts();
  static final List<Path> backCoreSurfaceParts = _backSurfaceParts();
  static final List<Path> frontHandParts = _frontHandParts();
  static final List<Path> backHandParts = _backHandParts();
  static final List<Path> frontFootParts = _frontFootParts();
  static final List<Path> backFootParts = _backFootParts();
  static final List<Path> frontSurfaceParts = [
    ...frontCoreSurfaceParts,
    ...frontHandParts,
    ...frontFootParts,
  ];
  static final List<Path> backSurfaceParts = [
    ...backCoreSurfaceParts,
    ...backHandParts,
    ...backFootParts,
  ];
  static final List<Path> frontSurfaceDetails = _frontSurfaceDetails();
  static final List<Path> backSurfaceDetails = _backSurfaceDetails();

  static final List<Path> frontDetails = [
    _line((path) {
      path
        ..moveTo(160, 29)
        ..lineTo(160, 79);
    }),
    _line((path) {
      path
        ..moveTo(145, 48)
        ..cubicTo(153, 45, 167, 45, 175, 48);
    }),
    _line((path) {
      path
        ..moveTo(139, 62)
        ..cubicTo(143, 73, 149, 81, 160, 84)
        ..cubicTo(171, 81, 177, 73, 181, 62);
    }),
    _line((path) {
      path
        ..moveTo(145, 89)
        ..cubicTo(141, 102, 132, 110, 119, 117);
    }),
    _line((path) {
      path
        ..moveTo(175, 89)
        ..cubicTo(179, 102, 188, 110, 201, 117);
    }),
    _line((path) {
      path
        ..moveTo(119, 117)
        ..cubicTo(132, 114, 146, 116, 158, 124)
        ..cubicTo(146, 128, 134, 128, 123, 126);
    }),
    _line((path) {
      path
        ..moveTo(201, 117)
        ..cubicTo(188, 114, 174, 116, 162, 124)
        ..cubicTo(174, 128, 186, 128, 197, 126);
    }),
    _line((path) {
      path
        ..moveTo(160, 124)
        ..lineTo(160, 327);
    }),
    _line((path) {
      path
        ..moveTo(103, 155)
        ..cubicTo(99, 168, 99, 180, 105, 190);
    }),
    _line((path) {
      path
        ..moveTo(217, 155)
        ..cubicTo(221, 168, 221, 180, 215, 190);
    }),
    _line((path) {
      path
        ..moveTo(62, 250)
        ..cubicTo(69, 255, 80, 254, 88, 247);
    }),
    _line((path) {
      path
        ..moveTo(258, 250)
        ..cubicTo(251, 255, 240, 254, 232, 247);
    }),
    _line((path) {
      path
        ..moveTo(112, 327)
        ..cubicTo(128, 336, 145, 340, 160, 346)
        ..cubicTo(175, 340, 192, 336, 208, 327);
    }),
    _line((path) {
      path
        ..moveTo(111, 489)
        ..cubicTo(124, 499, 140, 500, 153, 489);
    }),
    _line((path) {
      path
        ..moveTo(167, 489)
        ..cubicTo(180, 500, 196, 499, 209, 489);
    }),
    _line((path) {
      path
        ..moveTo(110, 641)
        ..cubicTo(121, 648, 134, 648, 145, 641);
    }),
    _line((path) {
      path
        ..moveTo(175, 641)
        ..cubicTo(186, 648, 199, 648, 210, 641);
    }),
    _line((path) {
      path
        ..moveTo(250, 354)
        ..cubicTo(251, 364, 254, 374, 258, 381);
    }),
    _line((path) {
      path
        ..moveTo(70, 354)
        ..cubicTo(69, 364, 66, 374, 62, 381);
    }),
    _line((path) {
      path
        ..moveTo(179, 695)
        ..cubicTo(190, 700, 205, 701, 217, 697);
    }),
    _line((path) {
      path
        ..moveTo(141, 695)
        ..cubicTo(130, 700, 115, 701, 103, 697);
    }),
  ];

  static final List<Path> backDetails = [
    _line((path) {
      path
        ..moveTo(142, 58)
        ..cubicTo(150, 65, 170, 65, 178, 58);
    }),
    _line((path) {
      path
        ..moveTo(146, 89)
        ..cubicTo(144, 104, 134, 112, 118, 120)
        ..cubicTo(133, 121, 147, 129, 158, 141);
    }),
    _line((path) {
      path
        ..moveTo(174, 89)
        ..cubicTo(176, 104, 186, 112, 202, 120)
        ..cubicTo(187, 121, 173, 129, 162, 141);
    }),
    _line((path) {
      path
        ..moveTo(160, 97)
        ..lineTo(160, 327);
    }),
    _line((path) {
      path
        ..moveTo(110, 143)
        ..cubicTo(124, 151, 139, 160, 151, 173)
        ..cubicTo(135, 170, 119, 169, 103, 176);
    }),
    _line((path) {
      path
        ..moveTo(210, 143)
        ..cubicTo(196, 151, 181, 160, 169, 173)
        ..cubicTo(185, 170, 201, 169, 217, 176);
    }),
    _line((path) {
      path
        ..moveTo(103, 176)
        ..cubicTo(112, 204, 119, 237, 119, 287);
    }),
    _line((path) {
      path
        ..moveTo(217, 176)
        ..cubicTo(208, 204, 201, 237, 201, 287);
    }),
    _line((path) {
      path
        ..moveTo(62, 251)
        ..cubicTo(69, 256, 80, 255, 89, 249);
    }),
    _line((path) {
      path
        ..moveTo(258, 251)
        ..cubicTo(251, 256, 240, 255, 231, 249);
    }),
    _line((path) {
      path
        ..moveTo(113, 322)
        ..cubicTo(130, 333, 146, 337, 160, 340)
        ..cubicTo(174, 337, 190, 333, 207, 322);
    }),
    _line((path) {
      path
        ..moveTo(111, 500)
        ..cubicTo(124, 510, 140, 511, 153, 499);
    }),
    _line((path) {
      path
        ..moveTo(167, 499)
        ..cubicTo(180, 511, 196, 510, 209, 500);
    }),
    _line((path) {
      path
        ..moveTo(109, 642)
        ..cubicTo(121, 649, 134, 649, 146, 641);
    }),
    _line((path) {
      path
        ..moveTo(174, 641)
        ..cubicTo(186, 649, 199, 649, 211, 642);
    }),
    _line((path) {
      path
        ..moveTo(250, 355)
        ..cubicTo(251, 365, 254, 375, 258, 382);
    }),
    _line((path) {
      path
        ..moveTo(70, 355)
        ..cubicTo(69, 365, 66, 375, 62, 382);
    }),
    _line((path) {
      path
        ..moveTo(179, 696)
        ..cubicTo(190, 701, 205, 702, 217, 698);
    }),
    _line((path) {
      path
        ..moveTo(141, 696)
        ..cubicTo(130, 701, 115, 702, 103, 698);
    }),
  ];

  static final List<Path> frontConnectors = [
    _line((path) {
      path
        ..moveTo(99, 151)
        ..cubicTo(107, 148, 111, 146, 116, 142);
    }),
    _line((path) {
      path
        ..moveTo(221, 151)
        ..cubicTo(213, 148, 209, 146, 204, 142);
    }),
    _line((path) {
      path
        ..moveTo(116, 197)
        ..cubicTo(118, 203, 121, 208, 127, 213);
    }),
    _line((path) {
      path
        ..moveTo(204, 197)
        ..cubicTo(202, 203, 199, 208, 193, 213);
    }),
    _line((path) {
      path
        ..moveTo(123, 293)
        ..cubicTo(120, 311, 118, 329, 121, 348);
    }),
    _line((path) {
      path
        ..moveTo(197, 293)
        ..cubicTo(200, 311, 202, 329, 199, 348);
    }),
  ];

  static final List<Path> backConnectors = [
    _line((path) {
      path
        ..moveTo(116, 143)
        ..cubicTo(111, 150, 108, 157, 106, 165);
    }),
    _line((path) {
      path
        ..moveTo(204, 143)
        ..cubicTo(209, 150, 212, 157, 214, 165);
    }),
    _line((path) {
      path
        ..moveTo(119, 286)
        ..cubicTo(118, 300, 119, 314, 125, 326);
    }),
    _line((path) {
      path
        ..moveTo(201, 286)
        ..cubicTo(202, 300, 201, 314, 195, 326);
    }),
    _line((path) {
      path
        ..moveTo(123, 389)
        ..cubicTo(120, 397, 118, 405, 118, 414);
    }),
    _line((path) {
      path
        ..moveTo(197, 389)
        ..cubicTo(200, 397, 202, 405, 202, 414);
    }),
  ];

  static final List<Path> frontTendons = [
    ..._mirroredShapes(
      _shape((path) {
        path
          ..moveTo(96, 146)
          ..cubicTo(103, 141, 110, 142, 115, 147)
          ..lineTo(112, 176)
          ..cubicTo(105, 171, 99, 163, 96, 154)
          ..close();
      }),
    ),
    ..._mirroredShapes(
      _shape((path) {
        path
          ..moveTo(98, 157)
          ..cubicTo(106, 159, 111, 168, 112, 178)
          ..cubicTo(110, 189, 106, 197, 101, 202)
          ..cubicTo(98, 185, 96, 170, 98, 157)
          ..close();
      }),
    ),
    ..._mirroredShapes(
      _shape((path) {
        path
          ..moveTo(111, 194)
          ..cubicTo(119, 202, 128, 210, 135, 220)
          ..lineTo(132, 239)
          ..cubicTo(123, 228, 116, 217, 110, 207)
          ..close();
      }),
    ),
    ..._mirroredShapes(
      _shape((path) {
        path
          ..moveTo(118, 305)
          ..cubicTo(128, 315, 138, 327, 145, 343)
          ..cubicTo(138, 348, 127, 353, 118, 357)
          ..cubicTo(114, 345, 114, 321, 118, 305)
          ..close();
      }),
    ),
    ..._mirroredShapes(
      _shape((path) {
        path
          ..moveTo(119, 483)
          ..cubicTo(128, 490, 140, 492, 152, 485)
          ..cubicTo(153, 497, 151, 508, 147, 518)
          ..cubicTo(134, 522, 123, 518, 118, 509)
          ..close();
      }),
    ),
  ];

  static final List<Path> backTendons = [
    ..._mirroredShapes(
      _shape((path) {
        path
          ..moveTo(96, 148)
          ..cubicTo(103, 141, 111, 141, 118, 146)
          ..cubicTo(115, 157, 111, 168, 106, 177)
          ..cubicTo(101, 169, 98, 159, 96, 148)
          ..close();
      }),
    ),
    ..._mirroredShapes(
      _shape((path) {
        path
          ..moveTo(105, 158)
          ..cubicTo(115, 153, 126, 158, 137, 171)
          ..cubicTo(132, 178, 126, 186, 121, 195)
          ..cubicTo(114, 181, 109, 169, 105, 158)
          ..close();
      }),
    ),
    ..._mirroredShapes(
      _shape((path) {
        path
          ..moveTo(121, 284)
          ..cubicTo(132, 298, 144, 311, 155, 321)
          ..cubicTo(145, 328, 130, 328, 116, 319)
          ..cubicTo(116, 307, 117, 294, 121, 284)
          ..close();
      }),
    ),
    ..._mirroredShapes(
      _shape((path) {
        path
          ..moveTo(118, 496)
          ..cubicTo(128, 504, 140, 506, 152, 499)
          ..cubicTo(153, 510, 151, 520, 147, 530)
          ..cubicTo(134, 534, 123, 530, 118, 521)
          ..close();
      }),
    ),
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
          ..moveTo(113, 202)
          ..cubicTo(119, 210, 128, 217, 135, 221)
          ..cubicTo(132, 246, 132, 276, 138, 301)
          ..cubicTo(130, 298, 123, 289, 118, 273)
          ..cubicTo(113, 250, 112, 221, 113, 202)
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
          ..moveTo(122, 350)
          ..cubicTo(132, 344, 146, 348, 153, 362)
          ..cubicTo(153, 398, 149, 445, 142, 482)
          ..cubicTo(135, 489, 124, 487, 119, 476)
          ..cubicTo(116, 438, 117, 382, 122, 350)
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
          ..moveTo(119, 512)
          ..cubicTo(128, 504, 139, 512, 143, 526)
          ..cubicTo(142, 562, 137, 606, 130, 638)
          ..cubicTo(122, 635, 117, 619, 114, 599)
          ..cubicTo(113, 565, 113, 533, 119, 512)
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
          ..moveTo(112, 165)
          ..cubicTo(123, 163, 134, 173, 139, 185)
          ..cubicTo(137, 213, 133, 253, 120, 287)
          ..cubicTo(108, 281, 102, 262, 101, 239)
          ..cubicTo(100, 213, 103, 184, 112, 165)
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
          ..moveTo(118, 330)
          ..cubicTo(130, 324, 145, 325, 158, 334)
          ..lineTo(158, 388)
          ..cubicTo(144, 396, 127, 393, 116, 382)
          ..cubicTo(113, 364, 113, 345, 118, 330)
          ..close();
      }),
    ),
    ..._pair(
      id: 'back.hamstrings',
      region: MuscleRegion.hamstrings,
      view: MuscleBodyView.back,
      left: _shape((path) {
        path
          ..moveTo(119, 392)
          ..cubicTo(131, 399, 143, 399, 154, 391)
          ..cubicTo(153, 429, 149, 475, 143, 507)
          ..cubicTo(134, 512, 123, 506, 117, 492)
          ..cubicTo(114, 454, 115, 416, 119, 392)
          ..close();
      }),
    ),
    ..._pair(
      id: 'back.calves',
      region: MuscleRegion.calves,
      view: MuscleBodyView.back,
      left: _shape((path) {
        path
          ..moveTo(119, 517)
          ..cubicTo(129, 507, 140, 515, 144, 531)
          ..cubicTo(143, 570, 137, 610, 129, 639)
          ..cubicTo(121, 635, 116, 619, 114, 598)
          ..cubicTo(113, 564, 113, 535, 119, 517)
          ..close();
      }),
      hitSlop: 3,
    ),
  ];

  static final Path frontBody = _buildFittedBody(
    core: _frontFittedCore(),
    head: frontHead,
    surfaceParts: frontSurfaceParts,
    tendons: frontTendons,
    muscles: frontPaths,
  );

  static final Path backBody = _buildFittedBody(
    core: _backFittedCore(),
    head: backHead,
    surfaceParts: backSurfaceParts,
    tendons: backTendons,
    muscles: backPaths,
  );

  static List<SvgMusclePath> pathsFor(MuscleBodyView view) =>
      view == MuscleBodyView.front ? frontPaths : backPaths;

  static Path bodyFor(MuscleBodyView view) =>
      view == MuscleBodyView.front ? frontBody : backBody;

  static List<Path> detailsFor(MuscleBodyView view) =>
      view == MuscleBodyView.front ? frontDetails : backDetails;

  static List<Path> connectorsFor(MuscleBodyView view) =>
      view == MuscleBodyView.front ? frontConnectors : backConnectors;

  static List<Path> tendonsFor(MuscleBodyView view) =>
      view == MuscleBodyView.front ? frontTendons : backTendons;

  static Path headFor(MuscleBodyView view) =>
      view == MuscleBodyView.front ? frontHead : backHead;

  static List<Path> surfacePartsFor(MuscleBodyView view) =>
      view == MuscleBodyView.front ? frontSurfaceParts : backSurfaceParts;

  static List<Path> coreSurfacePartsFor(MuscleBodyView view) =>
      view == MuscleBodyView.front
      ? frontCoreSurfaceParts
      : backCoreSurfaceParts;

  static List<Path> handPartsFor(MuscleBodyView view) =>
      view == MuscleBodyView.front ? frontHandParts : backHandParts;

  static List<Path> footPartsFor(MuscleBodyView view) =>
      view == MuscleBodyView.front ? frontFootParts : backFootParts;

  static List<Path> surfaceDetailsFor(MuscleBodyView view) =>
      view == MuscleBodyView.front ? frontSurfaceDetails : backSurfaceDetails;
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

Path _frontFittedCore() => _shape((path) {
  path
    ..moveTo(160, 7)
    ..cubicTo(176, 7, 185, 19, 187, 34)
    ..cubicTo(189, 48, 186, 65, 178, 78)
    ..cubicTo(175, 84, 172, 90, 173, 103)
    ..cubicTo(191, 106, 207, 110, 220, 116)
    ..cubicTo(232, 117, 241, 123, 244, 133)
    ..cubicTo(248, 144, 244, 155, 236, 163)
    ..cubicTo(246, 181, 252, 211, 251, 235)
    ..cubicTo(260, 259, 264, 303, 259, 329)
    ..cubicTo(258, 336, 255, 340, 251, 342)
    ..cubicTo(246, 343, 240, 341, 236, 337)
    ..cubicTo(233, 306, 230, 270, 232, 239)
    ..cubicTo(229, 210, 224, 181, 218, 163)
    ..cubicTo(214, 170, 212, 179, 211, 190)
    ..cubicTo(214, 214, 212, 242, 208, 270)
    ..cubicTo(207, 292, 206, 314, 206, 331)
    ..cubicTo(205, 350, 206, 382, 204, 414)
    ..cubicTo(203, 445, 202, 472, 202, 490)
    ..cubicTo(208, 500, 208, 511, 205, 520)
    ..cubicTo(209, 550, 208, 603, 205, 639)
    ..cubicTo(207, 655, 205, 669, 203, 679)
    ..cubicTo(194, 684, 183, 684, 174, 679)
    ..cubicTo(171, 632, 168, 580, 166, 531)
    ..cubicTo(164, 482, 164, 416, 166, 382)
    ..cubicTo(166, 370, 164, 362, 160, 356)
    ..cubicTo(156, 362, 154, 370, 154, 382)
    ..cubicTo(156, 416, 156, 482, 154, 531)
    ..cubicTo(152, 580, 149, 632, 146, 679)
    ..cubicTo(137, 684, 126, 684, 117, 679)
    ..cubicTo(115, 669, 113, 655, 112, 641)
    ..cubicTo(112, 603, 111, 550, 115, 520)
    ..cubicTo(112, 511, 112, 500, 116, 490)
    ..cubicTo(118, 472, 117, 445, 116, 414)
    ..cubicTo(114, 382, 115, 350, 114, 331)
    ..cubicTo(114, 314, 113, 292, 112, 270)
    ..cubicTo(108, 242, 106, 214, 109, 190)
    ..cubicTo(108, 179, 106, 170, 102, 163)
    ..cubicTo(96, 181, 91, 210, 88, 239)
    ..cubicTo(90, 270, 87, 306, 84, 337)
    ..cubicTo(80, 341, 74, 343, 69, 342)
    ..cubicTo(65, 340, 62, 336, 61, 329)
    ..cubicTo(56, 303, 60, 259, 69, 235)
    ..cubicTo(68, 211, 74, 181, 84, 163)
    ..cubicTo(76, 155, 72, 144, 76, 133)
    ..cubicTo(79, 123, 88, 117, 100, 116)
    ..cubicTo(113, 110, 129, 106, 147, 103)
    ..cubicTo(148, 90, 145, 84, 142, 78)
    ..cubicTo(134, 65, 131, 48, 133, 34)
    ..cubicTo(135, 19, 144, 7, 160, 7)
    ..close();
});

Path _backFittedCore() => _shape((path) {
  path
    ..moveTo(160, 7)
    ..cubicTo(176, 7, 185, 19, 187, 35)
    ..cubicTo(189, 49, 186, 66, 178, 79)
    ..cubicTo(175, 85, 172, 91, 174, 103)
    ..cubicTo(192, 106, 209, 110, 222, 116)
    ..cubicTo(234, 118, 242, 125, 245, 135)
    ..cubicTo(248, 146, 244, 157, 236, 165)
    ..cubicTo(246, 184, 252, 213, 251, 237)
    ..cubicTo(260, 261, 264, 304, 259, 330)
    ..cubicTo(258, 337, 255, 341, 251, 343)
    ..cubicTo(246, 344, 240, 342, 236, 338)
    ..cubicTo(233, 307, 230, 272, 232, 241)
    ..cubicTo(229, 212, 224, 183, 218, 165)
    ..cubicTo(215, 174, 212, 185, 212, 197)
    ..cubicTo(214, 222, 212, 254, 208, 284)
    ..cubicTo(207, 306, 207, 323, 206, 337)
    ..cubicTo(205, 353, 206, 383, 204, 414)
    ..cubicTo(203, 447, 202, 477, 202, 497)
    ..cubicTo(208, 508, 208, 520, 205, 530)
    ..cubicTo(209, 560, 208, 605, 205, 640)
    ..cubicTo(207, 656, 205, 670, 203, 680)
    ..cubicTo(194, 685, 183, 685, 174, 680)
    ..cubicTo(171, 634, 168, 582, 166, 533)
    ..cubicTo(164, 484, 164, 420, 166, 388)
    ..cubicTo(166, 376, 164, 366, 160, 360)
    ..cubicTo(156, 366, 154, 376, 154, 388)
    ..cubicTo(156, 420, 156, 484, 154, 533)
    ..cubicTo(152, 582, 149, 634, 146, 680)
    ..cubicTo(137, 685, 126, 685, 117, 680)
    ..cubicTo(115, 670, 113, 656, 112, 642)
    ..cubicTo(112, 605, 111, 560, 115, 530)
    ..cubicTo(112, 520, 112, 508, 116, 497)
    ..cubicTo(118, 477, 117, 447, 116, 414)
    ..cubicTo(114, 383, 115, 353, 114, 337)
    ..cubicTo(113, 323, 113, 306, 112, 284)
    ..cubicTo(108, 254, 106, 222, 108, 197)
    ..cubicTo(108, 185, 105, 174, 102, 165)
    ..cubicTo(96, 183, 91, 212, 88, 241)
    ..cubicTo(90, 272, 87, 307, 84, 338)
    ..cubicTo(80, 342, 74, 344, 69, 343)
    ..cubicTo(65, 341, 62, 337, 61, 330)
    ..cubicTo(56, 304, 60, 261, 69, 237)
    ..cubicTo(68, 213, 74, 184, 84, 165)
    ..cubicTo(76, 157, 72, 146, 75, 135)
    ..cubicTo(78, 125, 86, 118, 98, 116)
    ..cubicTo(111, 110, 128, 106, 146, 103)
    ..cubicTo(148, 91, 145, 85, 142, 79)
    ..cubicTo(134, 66, 131, 49, 133, 35)
    ..cubicTo(135, 19, 144, 7, 160, 7)
    ..close();
});

Path _frontHead() => _shape((path) {
  path
    ..moveTo(160, 8)
    ..cubicTo(176, 8, 185, 19, 187, 34)
    ..cubicTo(189, 44, 188, 55, 184, 64)
    ..cubicTo(180, 75, 172, 85, 160, 90)
    ..cubicTo(148, 85, 140, 75, 136, 64)
    ..cubicTo(132, 55, 131, 44, 133, 34)
    ..cubicTo(135, 19, 144, 8, 160, 8)
    ..close();
});

Path _backHead() => _shape((path) {
  path
    ..moveTo(160, 8)
    ..cubicTo(176, 8, 185, 19, 187, 35)
    ..cubicTo(189, 48, 186, 62, 180, 74)
    ..cubicTo(175, 83, 168, 88, 160, 91)
    ..cubicTo(152, 88, 145, 83, 140, 74)
    ..cubicTo(134, 62, 131, 48, 133, 35)
    ..cubicTo(135, 19, 144, 8, 160, 8)
    ..close();
});

List<Path> _frontSurfaceParts() => [
  _shape((path) {
    path
      ..moveTo(150, 84)
      ..cubicTo(154, 89, 166, 89, 170, 84)
      ..lineTo(171, 104)
      ..cubicTo(168, 112, 164, 117, 160, 120)
      ..cubicTo(156, 117, 152, 112, 149, 104)
      ..close();
  }),
  ..._mirroredShapes(
    _shape((path) {
      path
        ..moveTo(149, 87)
        ..cubicTo(151, 94, 151, 102, 146, 110)
        ..cubicTo(137, 112, 128, 115, 119, 120)
        ..cubicTo(132, 104, 142, 94, 149, 87)
        ..close();
    }),
  ),
  ..._mirroredShapes(
    _shape((path) {
      path
        ..moveTo(111, 190)
        ..cubicTo(119, 196, 126, 201, 134, 205)
        ..lineTo(131, 216)
        ..cubicTo(123, 213, 116, 208, 109, 201)
        ..close();
    }),
  ),
  ..._mirroredShapes(
    _shape((path) {
      path
        ..moveTo(109, 204)
        ..cubicTo(117, 211, 124, 216, 131, 220)
        ..lineTo(129, 231)
        ..cubicTo(120, 227, 113, 222, 107, 215)
        ..close();
    }),
  ),
  ..._mirroredShapes(
    _shape((path) {
      path
        ..moveTo(107, 219)
        ..cubicTo(114, 226, 122, 232, 129, 236)
        ..lineTo(128, 247)
        ..cubicTo(119, 244, 111, 238, 105, 231)
        ..close();
    }),
  ),
  ..._mirroredShapes(
    _shape((path) {
      path
        ..moveTo(118, 302)
        ..cubicTo(128, 311, 140, 321, 151, 340)
        ..cubicTo(139, 342, 126, 347, 116, 354)
        ..cubicTo(114, 338, 114, 319, 118, 302)
        ..close();
    }),
  ),
  ..._mirroredShapes(
    _shape((path) {
      path
        ..moveTo(119, 483)
        ..cubicTo(127, 490, 139, 492, 149, 486)
        ..cubicTo(151, 497, 148, 509, 142, 517)
        ..cubicTo(131, 520, 122, 516, 118, 506)
        ..close();
    }),
  ),
  ..._mirroredShapes(
    _shape((path) {
      path
        ..moveTo(132, 516)
        ..cubicTo(140, 520, 145, 529, 145, 542)
        ..cubicTo(143, 576, 139, 616, 132, 646)
        ..cubicTo(127, 639, 124, 625, 125, 608)
        ..cubicTo(126, 570, 128, 537, 132, 516)
        ..close();
    }),
  ),
];

List<Path> _backSurfaceParts() => [
  _shape((path) {
    path
      ..moveTo(150, 85)
      ..cubicTo(154, 90, 166, 90, 170, 85)
      ..lineTo(172, 104)
      ..cubicTo(168, 113, 164, 119, 160, 122)
      ..cubicTo(156, 119, 152, 113, 148, 104)
      ..close();
  }),
  ..._mirroredShapes(
    _shape((path) {
      path
        ..moveTo(149, 88)
        ..cubicTo(151, 97, 148, 107, 140, 116)
        ..cubicTo(131, 116, 123, 119, 116, 124)
        ..cubicTo(129, 108, 141, 96, 149, 88)
        ..close();
    }),
  ),
  ..._mirroredShapes(
    _shape((path) {
      path
        ..moveTo(105, 151)
        ..cubicTo(117, 147, 129, 153, 139, 166)
        ..lineTo(132, 177)
        ..cubicTo(122, 169, 113, 165, 104, 166)
        ..close();
    }),
  ),
  ..._mirroredShapes(
    _shape((path) {
      path
        ..moveTo(121, 287)
        ..cubicTo(132, 301, 145, 313, 156, 322)
        ..cubicTo(144, 329, 130, 329, 116, 320)
        ..cubicTo(116, 307, 117, 296, 121, 287)
        ..close();
    }),
  ),
  ..._mirroredShapes(
    _shape((path) {
      path
        ..moveTo(118, 495)
        ..cubicTo(127, 503, 140, 506, 151, 499)
        ..cubicTo(152, 511, 149, 522, 143, 531)
        ..cubicTo(132, 534, 123, 529, 118, 519)
        ..close();
    }),
  ),
  ..._mirroredShapes(
    _shape((path) {
      path
        ..moveTo(130, 526)
        ..cubicTo(139, 531, 144, 542, 144, 555)
        ..cubicTo(141, 588, 137, 620, 130, 646)
        ..cubicTo(124, 638, 122, 624, 123, 607)
        ..cubicTo(124, 573, 126, 545, 130, 526)
        ..close();
    }),
  ),
];

List<Path> _frontHandParts() {
  final palm = _shape((path) {
    path
      ..moveTo(60, 326)
      ..cubicTo(66, 321, 76, 323, 80, 330)
      ..cubicTo(82, 341, 79, 352, 73, 359)
      ..cubicTo(66, 360, 59, 355, 56, 347)
      ..cubicTo(55, 338, 57, 331, 60, 326)
      ..close();
  });
  final thumb = _shape((path) {
    path
      ..moveTo(75, 341)
      ..cubicTo(80, 342, 84, 348, 84, 354)
      ..lineTo(82, 370)
      ..cubicTo(81, 376, 77, 377, 74, 372)
      ..lineTo(72, 355)
      ..close();
  });
  final index = _shape((path) {
    path
      ..moveTo(68, 354)
      ..cubicTo(72, 352, 75, 355, 75, 360)
      ..lineTo(73, 380)
      ..cubicTo(72, 386, 67, 386, 66, 380)
      ..lineTo(66, 360)
      ..close();
  });
  final middle = _shape((path) {
    path
      ..moveTo(62, 353)
      ..cubicTo(66, 352, 69, 355, 69, 360)
      ..lineTo(66, 383)
      ..cubicTo(65, 389, 60, 388, 59, 382)
      ..lineTo(59, 360)
      ..close();
  });
  final ring = _shape((path) {
    path
      ..moveTo(57, 351)
      ..cubicTo(60, 351, 63, 354, 63, 359)
      ..lineTo(59, 379)
      ..cubicTo(58, 384, 53, 382, 53, 377)
      ..lineTo(54, 357)
      ..close();
  });
  final little = _shape((path) {
    path
      ..moveTo(53, 347)
      ..cubicTo(56, 347, 58, 351, 57, 356)
      ..lineTo(53, 372)
      ..cubicTo(51, 377, 47, 374, 48, 369)
      ..lineTo(50, 352)
      ..close();
  });
  return [
    ..._mirroredShapes(palm),
    ..._mirroredShapes(thumb),
    ..._mirroredShapes(index),
    ..._mirroredShapes(middle),
    ..._mirroredShapes(ring),
    ..._mirroredShapes(little),
  ];
}

List<Path> _backHandParts() {
  final palm = _shape((path) {
    path
      ..moveTo(59, 326)
      ..cubicTo(66, 321, 76, 324, 80, 331)
      ..cubicTo(81, 343, 78, 353, 72, 359)
      ..cubicTo(65, 360, 58, 354, 55, 346)
      ..cubicTo(54, 338, 56, 331, 59, 326)
      ..close();
  });
  final fingers = <Path>[
    _shape((path) {
      path
        ..moveTo(74, 349)
        ..cubicTo(79, 350, 82, 354, 82, 359)
        ..lineTo(80, 374)
        ..cubicTo(79, 379, 75, 379, 73, 374)
        ..lineTo(71, 357)
        ..close();
    }),
    _shape((path) {
      path
        ..moveTo(67, 354)
        ..cubicTo(71, 353, 74, 356, 74, 361)
        ..lineTo(72, 381)
        ..cubicTo(71, 387, 66, 387, 65, 381)
        ..lineTo(65, 360)
        ..close();
    }),
    _shape((path) {
      path
        ..moveTo(61, 353)
        ..cubicTo(65, 352, 68, 355, 68, 360)
        ..lineTo(65, 384)
        ..cubicTo(64, 390, 59, 389, 58, 383)
        ..lineTo(58, 360)
        ..close();
    }),
    _shape((path) {
      path
        ..moveTo(55, 351)
        ..cubicTo(59, 351, 61, 354, 61, 359)
        ..lineTo(58, 379)
        ..cubicTo(57, 384, 52, 383, 52, 377)
        ..lineTo(53, 357)
        ..close();
    }),
    _shape((path) {
      path
        ..moveTo(51, 347)
        ..cubicTo(54, 347, 56, 351, 55, 356)
        ..lineTo(51, 372)
        ..cubicTo(49, 377, 45, 374, 46, 369)
        ..lineTo(48, 352)
        ..close();
    }),
  ];
  return [
    ..._mirroredShapes(palm),
    for (final finger in fingers) ..._mirroredShapes(finger),
  ];
}

List<Path> _frontFootParts() {
  final ankle = _shape((path) {
    path
      ..moveTo(116, 641)
      ..cubicTo(123, 646, 135, 646, 141, 640)
      ..cubicTo(140, 655, 141, 670, 143, 679)
      ..cubicTo(136, 684, 123, 685, 115, 679)
      ..cubicTo(117, 665, 117, 652, 116, 641)
      ..close();
  });
  final midFoot = _shape((path) {
    path
      ..moveTo(115, 676)
      ..cubicTo(123, 681, 136, 682, 143, 677)
      ..cubicTo(148, 683, 149, 693, 143, 699)
      ..cubicTo(133, 704, 114, 704, 105, 699)
      ..cubicTo(101, 691, 106, 681, 115, 676)
      ..close();
  });
  return [..._mirroredShapes(ankle), ..._mirroredShapes(midFoot)];
}

List<Path> _backFootParts() {
  final achilles = _shape((path) {
    path
      ..moveTo(118, 641)
      ..cubicTo(124, 645, 134, 645, 140, 640)
      ..cubicTo(139, 655, 140, 670, 142, 680)
      ..cubicTo(135, 685, 123, 685, 115, 680)
      ..cubicTo(117, 665, 118, 652, 118, 641)
      ..close();
  });
  final heel = _shape((path) {
    path
      ..moveTo(114, 677)
      ..cubicTo(122, 682, 136, 682, 143, 677)
      ..cubicTo(148, 684, 148, 694, 142, 700)
      ..cubicTo(132, 704, 114, 704, 105, 699)
      ..cubicTo(102, 690, 106, 681, 114, 677)
      ..close();
  });
  return [..._mirroredShapes(achilles), ..._mirroredShapes(heel)];
}

List<Path> _frontSurfaceDetails() => [
  ..._mirroredShapes(
    _line((path) {
      path
        ..moveTo(61, 333)
        ..cubicTo(67, 337, 73, 337, 78, 333);
    }),
  ),
  ..._mirroredShapes(
    _line((path) {
      path
        ..moveTo(83, 166)
        ..cubicTo(78, 188, 77, 213, 80, 232);
    }),
  ),
  ..._mirroredShapes(
    _line((path) {
      path
        ..moveTo(75, 241)
        ..cubicTo(69, 267, 66, 299, 67, 322);
    }),
  ),
  ..._mirroredShapes(
    _line((path) {
      path
        ..moveTo(128, 354)
        ..cubicTo(121, 390, 120, 438, 126, 481);
    }),
  ),
  ..._mirroredShapes(
    _line((path) {
      path
        ..moveTo(122, 520)
        ..cubicTo(115, 551, 115, 602, 123, 635);
    }),
  ),
  ..._mirroredShapes(
    _line((path) {
      path
        ..moveTo(112, 689)
        ..cubicTo(123, 693, 136, 693, 145, 689);
    }),
  ),
];

List<Path> _backSurfaceDetails() => [
  ..._mirroredShapes(
    _line((path) {
      path
        ..moveTo(60, 333)
        ..cubicTo(67, 337, 73, 337, 78, 333);
    }),
  ),
  ..._mirroredShapes(
    _line((path) {
      path
        ..moveTo(84, 166)
        ..cubicTo(78, 190, 77, 216, 80, 234);
    }),
  ),
  ..._mirroredShapes(
    _line((path) {
      path
        ..moveTo(75, 242)
        ..cubicTo(69, 270, 66, 300, 67, 324);
    }),
  ),
  ..._mirroredShapes(
    _line((path) {
      path
        ..moveTo(128, 397)
        ..cubicTo(120, 428, 119, 472, 126, 503);
    }),
  ),
  ..._mirroredShapes(
    _line((path) {
      path
        ..moveTo(121, 527)
        ..cubicTo(114, 558, 114, 603, 122, 636);
    }),
  ),
  ..._mirroredShapes(
    _line((path) {
      path
        ..moveTo(111, 690)
        ..cubicTo(122, 694, 135, 694, 144, 690);
    }),
  ),
];

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

List<Path> _mirroredShapes(Path left) => [left, _mirror(left)];

Path _buildFittedBody({
  required Path core,
  required Path head,
  required List<Path> surfaceParts,
  required List<Path> tendons,
  required List<SvgMusclePath> muscles,
}) => _removeTinyContours(
  _unionPaths([
    core,
    head,
    ...surfaceParts,
    ...tendons,
    ...muscles.map((muscle) => muscle.path),
  ]),
);

Path _removeTinyContours(Path path) {
  final cleaned = Path();
  for (final metric in path.computeMetrics()) {
    final contour = metric.extractPath(0, metric.length);
    final bounds = contour.getBounds();
    if (bounds.width < 1 || bounds.height < 1) continue;
    cleaned.addPath(contour, Offset.zero);
  }
  return cleaned;
}

Path _unionPaths(List<Path> paths) {
  if (paths.isEmpty) return Path();
  var combined = paths.first;
  for (final path in paths.skip(1)) {
    combined = Path.combine(PathOperation.union, combined, path);
  }
  return combined;
}

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
