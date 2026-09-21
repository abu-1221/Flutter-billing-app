import 'package:billing_app/core/utils/app_validators.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AppValidators.required', () {
    final validator = AppValidators.required('Required');

    test('rejects empty and whitespace-only values', () {
      expect(validator(null), 'Required');
      expect(validator('   '), 'Required');
    });

    test('accepts non-empty values', () {
      expect(validator('Product'), isNull);
    });
  });

  group('AppValidators.price', () {
    test('accepts zero and positive finite values', () {
      expect(AppValidators.price('0'), isNull);
      expect(AppValidators.price('12.50'), isNull);
    });

    test('rejects empty, non-numeric, negative, and non-finite values', () {
      expect(AppValidators.price(''), 'Please enter a price');
      expect(AppValidators.price('twelve'), 'Please enter a valid number');
      expect(AppValidators.price('-1'), 'Price cannot be negative');
      expect(AppValidators.price('NaN'), 'Please enter a valid number');
      expect(AppValidators.price('Infinity'), 'Please enter a valid number');
    });
  });
}
