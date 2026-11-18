import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/feature/shared/presentation/china_region_data.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'municipalities expose a city level containing their districts',
    () async {
      final provinces = await loadChinaRegions();
      for (final (provinceCode, cityCode, name) in [
        ('110000', '110100', '北京市'),
        ('120000', '120100', '天津市'),
        ('310000', '310100', '上海市'),
        ('500000', '500100', '重庆市'),
      ]) {
        final province = provinces.singleWhere(
          (node) => node.code == provinceCode,
        );
        final city = province.children.single;
        expect(city.code, cityCode);
        expect(city.name, name);
        expect(city.children, isNotEmpty);
        expect(city.children.every((node) => node.children.isEmpty), isTrue);
      }
    },
  );

  test(
    'the bundled snapshot includes province, city, and district levels',
    () async {
      final provinces = await loadChinaRegions();
      final cities = provinces.expand((node) => node.children).toList();
      final districts = cities.expand((node) => node.children).toList();
      expect(provinces.length, greaterThanOrEqualTo(30));
      expect(cities.length, greaterThanOrEqualTo(300));
      expect(districts.length, greaterThanOrEqualTo(2000));
      expect(districts.every((node) => node.children.isEmpty), isTrue);
      final zhejiang = provinces.singleWhere((node) => node.code == '330000');
      final hangzhou = zhejiang.children.singleWhere(
        (node) => node.code == '330100',
      );
      expect(zhejiang.name, '浙江省');
      expect(hangzhou.name, '杭州市');
      expect(hangzhou.children, isNotEmpty);
    },
  );
}
