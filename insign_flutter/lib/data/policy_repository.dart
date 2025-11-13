import 'package:insign/core/config/api_config.dart';
import 'package:insign/data/services/api_client.dart';
import 'package:insign/models/policy.dart';

class PolicyRepository {
  Future<Policy?> fetchPrivacyPolicy() async {
    return ApiClient.requestNullable<Policy>(
      path: ApiConfig.policyPrivacy,
      method: 'GET',
      fromJson: (json) => Policy.fromJson(json),
    );
  }

  Future<Policy?> fetchTermsOfService() async {
    return ApiClient.requestNullable<Policy>(
      path: ApiConfig.policyTerms,
      method: 'GET',
      fromJson: (json) => Policy.fromJson(json),
    );
  }
}
