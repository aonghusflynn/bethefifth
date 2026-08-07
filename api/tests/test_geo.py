from services.geo import bounding_box, haversine_distance


def test_haversine_dublin_to_cork():
    # Dublin (53.3498, -6.2603) to Cork (51.8985, -8.4756) ≈ 220 km
    dist = haversine_distance(53.3498, -6.2603, 51.8985, -8.4756)
    assert 215 < dist < 225


def test_haversine_same_point():
    dist = haversine_distance(53.3498, -6.2603, 53.3498, -6.2603)
    assert dist == 0.0


def test_bounding_box():
    min_lat, max_lat, min_lng, max_lng = bounding_box(53.3498, -6.2603, 5.0)
    assert min_lat < 53.3498 < max_lat
    assert min_lng < -6.2603 < max_lng
    # 5km should be roughly 0.045 degrees latitude
    assert 0.04 < (max_lat - 53.3498) < 0.05
