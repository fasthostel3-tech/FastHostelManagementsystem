import 'package:flutter_test/flutter_test.dart';
import 'package:fast_hostel_system/models/hostel_model.dart';

void main() {
  test('HostelApplicationModel.getFeeAmount returns expected', () {
    expect(HostelApplicationModel.getFeeAmount(RoomType.single), 70000.0);
    expect(HostelApplicationModel.getFeeAmount(RoomType.double), 67000.0);
    expect(HostelApplicationModel.getFeeAmount(RoomType.shared), 42000.0);
  });
}
