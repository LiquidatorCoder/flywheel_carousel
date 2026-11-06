import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flywheel_carousel/flywheel_carousel.dart';

const _dpr = 3.0;
const _velocities = <double>[
  0, 20, 60, 101, 110, 160, 400, 780, 1500, 3000, 9000, //
];

class _Case {
  _Case(this.viewport, this.fraction, this.page, this.v, {double? drag})
    : physics = FreewheelPhysics(viewportFraction: fraction, dragCoefficient: drag ?? 0.35);

  final double viewport;
  final double fraction;
  final double page;
  final double v;
  final FreewheelPhysics physics;

  double get pw => viewport * fraction;
  double get off => math.max(0, viewport * (fraction - 1) / 2);
  double px(double p) => p * pw + off;
  double get pixels => px(page);
  FixedScrollMetrics metrics({double? min, double? max}) => FixedScrollMetrics(
    minScrollExtent: min ?? off,
    maxScrollExtent: max ?? px(100),
    pixels: pixels,
    viewportDimension: viewport,
    axisDirection: AxisDirection.right,
    devicePixelRatio: _dpr,
  );
  Tolerance get tol => physics.toleranceFor(metrics());
  Simulation? sim({double? min, double? max}) =>
      physics.createBallisticSimulation(metrics(min: min, max: max), v);
  @override
  String toString() => 'vp=$viewport f=$fraction page=$page v=$v';
}

class _Run {
  _Run(this.sim, this.doneAt, this.xs, this.dxs);
  final Simulation sim;
  final double doneAt;
  final List<double> xs;
  final List<double> dxs;
  double get end => xs.last;
}

bool _isSettle(Simulation s) => s.runtimeType.toString() == '_SettleSimulation';

/// Samples [sim] every millisecond until done (cap 20 s).
_Run _run(Simulation sim) {
  final xs = <double>[];
  final dxs = <double>[];
  var t = 0.0;
  for (var i = 0; i <= 20000; i++) {
    t = i / 1000;
    final x = sim.x(t);
    final dx = sim.dx(t);
    expect(x.isFinite && dx.isFinite, isTrue, reason: 'non-finite at t=$t');
    xs.add(x);
    dxs.add(dx);
    if (sim.isDone(t)) break;
  }
  return _Run(sim, sim.isDone(t) ? t : double.infinity, xs, dxs);
}

List<_Case> _grid({List<double> viewports = const [402, 874]}) => [
  for (final vp in viewports)
    for (final f in const [0.65, 1.2])
      for (var i = 0; i < 34; i++)
        for (final v in _velocities)
          for (final s in (v == 0 ? const [1.0] : const [1.0, -1.0]))
            _Case(vp, f, 50 + i * 0.03, v * s),
];

void main() {
  final cases = _grid();

  group('never throws / lands on grid', () {
    test('every case settles finitely on a page inside the extents', () {
      for (final c in cases) {
        final sim = c.sim();
        if (sim == null) {
          expect(
            (c.pixels - c.px(c.page.roundToDouble())).abs(),
            lessThan(c.tol.distance),
            reason: '$c returned null off-grid',
          );
          continue;
        }
        final r = _run(sim);
        expect(r.doneAt.isFinite, isTrue, reason: '$c never done');
        final p = (r.end - c.off) / c.pw;
        expect(
          (p - p.round()).abs() * c.pw,
          lessThan(c.tol.distance + 1e-6),
          reason: '$c ended off-grid at page $p',
        );
        expect(r.end, inInclusiveRange(c.off, c.px(100)), reason: '$c');
      }
    });

    test('direction: momentum never lands behind the current card', () {
      for (final c in cases.where((c) => c.v != 0)) {
        final sim = c.sim();
        if (sim == null) continue;
        final cur = c.page.round();
        final p = ((_run(sim).end - c.off) / c.pw).round();
        if (c.v > 0) {
          expect(p, greaterThanOrEqualTo(cur), reason: '$c');
        } else {
          expect(p, lessThanOrEqualTo(cur), reason: '$c');
        }
      }
    });
  });

  group('shape', () {
    test('no overshoot past the landing point (> 1 px)', () {
      for (final c in cases) {
        final sim = c.sim();
        if (sim == null) continue;
        final r = _run(sim);
        final dir = (r.end - c.pixels).sign;
        if (dir == 0) continue;
        for (final x in r.xs) {
          expect((x - r.end) * dir, lessThanOrEqualTo(1.0), reason: '$c');
        }
      }
    });

    test('coast never accelerates', () {
      var coasts = 0;
      for (final c in cases) {
        final sim = c.sim();
        if (sim == null || _isSettle(sim)) continue;
        coasts++;
        final r = _run(sim);
        for (var i = 1; i < r.dxs.length; i++) {
          expect(
            r.dxs[i].abs(),
            lessThanOrEqualTo(r.dxs[i - 1].abs() + 1e-6),
            reason: '$c accelerated at ${i}ms',
          );
        }
      }
      expect(coasts, greaterThan(100));
    });

    test('position and velocity are continuous (0.1 ms steps)', () {
      for (final v in const [1500.0, 3000.0, 9000.0, -9000.0]) {
        final c = _Case(402, 0.65, 10.3, v);
        final sim = c.sim()!;
        for (var t = 0.0; t < 5; t += 1e-4) {
          if (sim.isDone(t)) break;
          const dt = 1e-4;
          final dxMid = (sim.dx(t) + sim.dx(t + dt)) / 2;
          expect(
            (sim.x(t + dt) - sim.x(t) - dxMid * dt).abs(),
            lessThan(0.5),
            reason: '$c x jump at $t',
          );
          expect((sim.dx(t + dt) - sim.dx(t)).abs(), lessThan(5), reason: '$c dx jump at $t');
        }
      }
    });
  });

  group('timing', () {
    test('settles and pulls (|d| <= 1 page) finish in <= 0.5 s', () {
      var n = 0;
      for (final c in cases) {
        final sim = c.sim();
        if (sim == null || !_isSettle(sim)) continue;
        final r = _run(sim);
        if ((r.end - c.pixels).abs() > c.pw) continue;
        n++;
        expect(r.doneAt, lessThanOrEqualTo(0.5), reason: '$c');
      }
      expect(n, greaterThan(50));
    });

    test('slow flick from a page boundary (v=160) finishes in <= 0.5 s', () {
      for (final vp in const [402.0, 874.0]) {
        for (final f in const [0.65, 1.2]) {
          final c = _Case(vp, f, 50, 160);
          expect(_run(c.sim()!).doneAt, lessThanOrEqualTo(0.5), reason: '$c');
        }
      }
    });

    test('hard flicks stay bounded', () {
      var worst3000 = 0.0, worst9000 = 0.0, worstSnap = 0.0;
      for (final c in cases) {
        final sim = c.sim();
        if (sim == null) continue;
        final t = _run(sim).doneAt;
        if (_isSettle(sim)) worstSnap = math.max(worstSnap, t);
        if (c.v.abs() == 3000) worst3000 = math.max(worst3000, t);
        if (c.v.abs() == 9000) worst9000 = math.max(worst9000, t);
      }
      // ignore: avoid_print
      print('worstSnap=$worstSnap worst3000=$worst3000 worst9000=$worst9000');
      expect(worst3000, lessThanOrEqualTo(3.5));
      expect(worst9000, lessThanOrEqualTo(4.6));
    });
  });

  group('distance', () {
    test('|v| >= 400 lands on the rounded natural friction landing', () {
      for (final c in cases.where((c) => c.v.abs() >= 400)) {
        final natural = c.pixels + c.v / -math.log(0.35);
        final expected = ((natural - c.off) / c.pw).round();
        final p = ((_run(c.sim()!).end - c.off) / c.pw).round();
        expect(p, expected, reason: '$c');
      }
    });

    test('a larger dragCoefficient spins farther (FrictionSimulation semantics)', () {
      final far = _Case(402, 0.65, 50, 3000, drag: 0.5);
      final near = _Case(402, 0.65, 50, 3000, drag: 0.35);
      expect(_run(far.sim()!).end, greaterThan(_run(near.sim()!).end));
    });
  });

  group('non-loop clamp', () {
    // Natural landing (~page 15) is far beyond the last card (page 4).
    void expectEnds(ScrollPhysics? parent, double slackPages, {bool top = true}) {
      final c = _Case(400, 0.65, top ? 3.6 : 0.4, top ? 3000 : -3000);
      const base = FreewheelPhysics(viewportFraction: 0.65);
      final physics = parent == null ? base : base.applyTo(parent);
      final m = c.metrics(min: 0, max: c.px(4));
      final sim = physics.createBallisticSimulation(m, c.v)!;
      final r = _run(sim);
      final edge = top ? c.px(4) : 0.0;
      expect(r.end, closeTo(edge, c.tol.distance));
      final slack = slackPages * c.pw;
      if (top) {
        expect(r.xs.reduce(math.max), lessThanOrEqualTo(edge + slack));
      } else {
        expect(r.xs.reduce(math.min), greaterThanOrEqualTo(edge - slack));
      }
    }

    test('BouncingScrollPhysics parent: bounces, ends on last card', () {
      expectEnds(const BouncingScrollPhysics(), 0.6);
      expectEnds(const BouncingScrollPhysics(), 0.6, top: false);
    });

    test('ClampingScrollPhysics parent: its sim is used (boundary clamps)', () {
      // The parent's raw simulation runs past the edge; ScrollPosition's
      // boundary conditions then stop it on the end card.
      final c = _Case(400, 0.65, 3.6, 3000);
      final physics = const FreewheelPhysics(
        viewportFraction: 0.65,
      ).applyTo(const ClampingScrollPhysics());
      final sim = physics.createBallisticSimulation(c.metrics(min: 0, max: c.px(4)), c.v);
      expect(sim, isA<ClampingScrollSimulation>());
      expect(_run(sim!).xs.any((x) => x >= c.px(4)), isTrue);
    });

    test('no parent: coasts to the edge, no overshoot', () {
      expectEnds(null, 0);
      expectEnds(null, 0, top: false);
    });
  });

  group('speed bounds', () {
    test('coast never exceeds |v|; settle peaks <= 1.5|d|/T + |v|', () {
      for (final c in cases) {
        final sim = c.sim();
        if (sim == null) continue;
        final r = _run(sim);
        final peak = r.dxs.map((d) => d.abs()).reduce(math.max);
        if (_isSettle(sim)) {
          final d = (r.end - c.pixels).abs();
          expect(
            peak,
            lessThanOrEqualTo(1.52 * d / r.doneAt + c.v.abs() + 1e-6),
            reason: '$c settle lurch',
          );
        } else {
          expect(peak, lessThanOrEqualTo(c.v.abs() + 1e-6), reason: '$c');
        }
      }
    });
  });
}
