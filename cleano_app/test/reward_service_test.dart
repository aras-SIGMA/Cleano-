import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cleano_app/services/api_service.dart';
import 'package:cleano_app/services/reward_service.dart';

/// ApiService palsu khusus menguji method post/get pada RewardService.
class FakeApiService implements ApiService {
  FakeApiService({this.payload});

  Object? payload;
  String? lastPath;
  Object? lastData;

  @override
  Future<Response<T>> post<T>(String path, {Object? data}) async {
    lastPath = path;
    lastData = data;
    return Response<T>(
      requestOptions: RequestOptions(path: path),
      data: payload as T?,
      statusCode: 201,
    );
  }

  @override
  Future<Response<T>> get<T>(String path, {Map<String, dynamic>? query}) async {
    lastPath = path;
    return Response<T>(
      requestOptions: RequestOptions(path: path),
      data: payload as T?,
      statusCode: 200,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError(
        '${invocation.memberName} tidak dipakai di uji ini.',
      );
}

void main() {
  // Format respons asli redeem meletakkan field voucher langsung di data.
  Map<String, dynamic> redeemPayload() => {
        'success': true,
        'message': 'Voucher CLN-VCR-9K3M berhasil diklaim.',
        'data': {
          'id': 12,
          'voucher_code': 'CLN-VCR-9K3M',
          'user_id': 2,
          'reward_id': 1,
          'is_used': 0,
          'used_at': null,
          'created_at': '2026-11-21T10:00:00.000Z',
          'title': 'Potongan Hemat Rp 5.000',
          'description': 'Diskon langsung Rp 5.000 untuk semua paket laundry.',
          'discount_amount': 5000,
          'points_required': 50,
          'points_before': 150,
          'points_after': 100,
        },
      };

  test('redeem membaca field voucher yang disebar di data', () async {
    final api = FakeApiService(payload: redeemPayload());
    final voucher = await RewardService(apiService: api).redeem(1);

    expect(voucher.voucherCode, 'CLN-VCR-9K3M');
    expect(voucher.discountAmount, 5000);
    expect(voucher.isUsed, isFalse);
    expect(api.lastPath, '/api/rewards/redeem');
    expect(api.lastData, {'reward_id': 1});
  });

  test('redeem menolak data tanpa voucher_code, bukan menampilkan kartu kosong', () async {
    final api = FakeApiService(payload: {
      'success': true,
      'data': {
        'voucher': redeemPayload()['data'],
      },
    });

    // Tolak respons voucher tanpa kode agar UI tidak menampilkan kartu kosong.
    await expectLater(
      RewardService(apiService: api).redeem(1),
      throwsA(isA<ApiException>()),
    );
  });

  test('redeem menolak respons tanpa data', () async {
    final api = FakeApiService(payload: {'success': false});

    await expectLater(
      RewardService(apiService: api).redeem(1),
      throwsA(isA<ApiException>()),
    );
  });
}
