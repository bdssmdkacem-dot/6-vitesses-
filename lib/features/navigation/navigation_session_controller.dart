import 'navigation_models.dart';
import 'osrm_route_service.dart';

enum NavigationSessionStatus {
  idle,
  navigating,
  offRoute,
  rerouting,
  arrived,
}

class NavigationSessionController {
  NavigationSessionStatus status = NavigationSessionStatus.idle;
  OsrmRoute? route;
  DateTime? offRouteSince;
  DateTime? lastRerouteAttempt;

  bool get hasDestination => route?.destination != null;
  bool get rerouteInProgress => status == NavigationSessionStatus.rerouting;

  void start(OsrmRoute nextRoute) {
    route = nextRoute;
    status = NavigationSessionStatus.navigating;
    offRouteSince = null;
    lastRerouteAttempt = null;
  }

  void update(NavigationState state, DateTime now) {
    if (route == null) {
      status = NavigationSessionStatus.idle;
      offRouteSince = null;
      return;
    }

    if (state.arrived || state.remainingMeters <= 12) {
      status = NavigationSessionStatus.arrived;
      offRouteSince = null;
      return;
    }

    if (state.offRoute) {
      offRouteSince ??= now;
      if (now.difference(offRouteSince!) >= const Duration(seconds: 4) &&
          status != NavigationSessionStatus.rerouting) {
        status = NavigationSessionStatus.offRoute;
      }
      return;
    }

    offRouteSince = null;
    if (status != NavigationSessionStatus.rerouting) {
      status = NavigationSessionStatus.navigating;
    }
  }

  bool shouldReroute(DateTime now) {
    if (status != NavigationSessionStatus.offRoute ||
        route?.destination == null ||
        rerouteInProgress) {
      return false;
    }
    final last = lastRerouteAttempt;
    return last == null ||
        now.difference(last) >= const Duration(seconds: 20);
  }

  void beginReroute(DateTime now) {
    lastRerouteAttempt = now;
    status = NavigationSessionStatus.rerouting;
  }

  void rerouteSucceeded(OsrmRoute nextRoute) {
    route = nextRoute;
    status = NavigationSessionStatus.navigating;
    offRouteSince = null;
  }

  void rerouteFailed() {
    status = NavigationSessionStatus.offRoute;
  }

  void stop() {
    route = null;
    status = NavigationSessionStatus.idle;
    offRouteSince = null;
    lastRerouteAttempt = null;
  }
}
