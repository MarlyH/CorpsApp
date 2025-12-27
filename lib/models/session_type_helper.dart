enum SessionType { ages8to11, ages12to15, adults, all }

class SessionTypeHelper {
  static String format(SessionType s) {
    switch (s) {
      case SessionType.ages8to11: return 'Ages 8 to 11';
      case SessionType.ages12to15: return 'Ages 12 to 15';
      case SessionType.adults:     return 'Ages 16+';
      case SessionType.all:        return 'All Ages';
    }
  }
}
