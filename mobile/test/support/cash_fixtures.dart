const point = 'Punto 1 - Portería Principal USTA';
Map<String, dynamic> cashSession({bool closed = false}) => {
  'id': 1,
  'operator_id': 3,
  'operator_name': 'Taquilla principal',
  'point_name': point,
  'business_date': '2026-11-17',
  'status': closed ? 'CLOSED' : 'OPEN',
  'opening_amount': 10000,
  'opened_at': '2026-11-17T12:00:00Z',
  'closed_at': closed ? '2026-11-17T22:00:00Z' : null,
  'recharge_total': 20000,
  'recharge_count': 1,
  'expected_cash': 30000,
  'counted_cash': 30000,
  'retained_cash': 8000,
  'remitted_cash': 22000,
  'difference': 0,
  'reference': '11111111-1111-4111-8111-111111111111',
  'notes': '',
  'can_recharge': !closed,
};
Map<String, dynamic> cashCurrent({bool active = true, bool carried = false}) =>
    {
      'success': true,
      'session': active ? cashSession() : null,
      'business_date': '2026-11-17',
      'points': [
        {
          'point_name': point,
          'available': !active,
          'carried': carried,
          'opening_amount': carried ? 8000 : 0,
        },
      ],
    };
