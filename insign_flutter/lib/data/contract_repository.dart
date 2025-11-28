import 'dart:convert';
import 'dart:typed_data';

import 'package:insign/core/config/api_config.dart';
import 'package:insign/data/services/api_client.dart';
import 'package:insign/models/blockchain_verification_result.dart';
import 'package:insign/models/contract.dart';

class CreateContractPayload {
  final int? templateId;
  final String name;
  final String clientName;
  final String? clientContact;
  final String? clientEmail;
  final String? performerName;
  final String? performerEmail;
  final String? performerContact;
  final String? startDate;
  final String? endDate;
  final String? amount;
  final String? details;
  final Map<String, dynamic>? metadata;

  const CreateContractPayload({
    this.templateId,
    required this.name,
    required this.clientName,
    this.clientContact,
    this.clientEmail,
    this.performerName,
    this.performerEmail,
    this.performerContact,
    this.startDate,
    this.endDate,
    this.amount,
    this.details,
    this.metadata,
  });

  Map<String, dynamic> toJson() {
    return {
      if (templateId != null) 'templateId': templateId,
      'name': name,
      'clientName': clientName,
      if (clientContact != null) 'clientContact': clientContact,
      if (clientEmail != null) 'clientEmail': clientEmail,
      'performer': {
        if (performerName != null) 'performerName': performerName,
        if (performerEmail != null) 'performerEmail': performerEmail,
        if (performerContact != null) 'performerContact': performerContact,
      },
      if (startDate != null) 'startDate': startDate,
      if (endDate != null) 'endDate': endDate,
      if (amount != null) 'amount': amount,
      if (details != null) 'details': details,
      if (metadata != null) 'metadata': metadata,
    };
  }
}

class VerifyContractPerformerPayload {
  final String performerName;
  final String performerEmail;
  final String performerContact;

  const VerifyContractPerformerPayload({
    required this.performerName,
    required this.performerEmail,
    required this.performerContact,
  });

  Map<String, dynamic> toJson() {
    return {
      'performerName': performerName,
      'performerEmail': performerEmail,
      'performerContact': performerContact,
    };
  }
}

class CompleteContractSignaturePayload {
  final String imageData;
  final String source;
  final Map<String, dynamic>? recipientFormValues;

  const CompleteContractSignaturePayload({
    required this.imageData,
    required this.source,
    this.recipientFormValues,
  });

  Map<String, dynamic> toJson() {
    return {
      'imageData': imageData,
      'source': source,
      if (recipientFormValues != null && recipientFormValues!.isNotEmpty)
        'recipientFormValues': recipientFormValues,
    };
  }
}

class ContractRepository {
  Future<List<Contract>> fetchContracts({String? token}) async {
    return ApiClient.requestList<Contract>(
      path: ApiConfig.contracts,
      method: 'GET',
      token: token,
      fromJson: (json) => Contract.fromJson(json),
    );
  }

  Future<Contract> fetchContractDetail({required int id, String? token}) async {
    return ApiClient.request<Contract>(
      path: '${ApiConfig.contracts}/$id',
      method: 'GET',
      token: token,
      fromJson: (json) => Contract.fromJson(json),
    );
  }

  Future<Contract> createContract({
    required CreateContractPayload payload,
    String? token,
  }) async {
    return ApiClient.request<Contract>(
      path: ApiConfig.contracts,
      method: 'POST',
      body: payload.toJson(),
      token: token,
      fromJson: (json) => Contract.fromJson(json),
    );
  }

  Future<void> resendSignatureRequest({
    required int id,
    String? token,
  }) async {
    return ApiClient.requestVoid(
      path: '${ApiConfig.contracts}/$id/resend',
      method: 'POST',
      token: token,
    );
  }

  Future<Uint8List> downloadContractPdf({
    required int id,
    String? token,
  }) async {
    return ApiClient.requestBytes(
      path: '${ApiConfig.contracts}/$id/pdf',
      method: 'GET',
      token: token,
      accept: 'application/pdf',
    );
  }

  Future<Uint8List> downloadContractPdfByToken({
    required String signatureToken,
  }) async {
    return ApiClient.requestBytes(
      path: '${ApiConfig.contracts}/sign/$signatureToken/pdf',
      method: 'GET',
      accept: 'application/pdf',
    );
  }

  Future<Contract> verifyContractByToken({
    required String signatureToken,
    required VerifyContractPerformerPayload payload,
  }) async {
    return ApiClient.request<Contract>(
      path: '${ApiConfig.contracts}/sign/$signatureToken/verify',
      method: 'POST',
      body: payload.toJson(),
      fromJson: (json) => Contract.fromJson(json),
    );
  }

  Future<Contract> declineContractByToken({
    required String signatureToken,
  }) async {
    return ApiClient.request<Contract>(
      path: '${ApiConfig.contracts}/sign/$signatureToken/decline',
      method: 'POST',
      fromJson: (json) => Contract.fromJson(json),
    );
  }

  Future<Contract> completeContractByToken({
    required String signatureToken,
    required CompleteContractSignaturePayload payload,
  }) async {
    return ApiClient.request<Contract>(
      path: '${ApiConfig.contracts}/sign/$signatureToken/complete',
      method: 'POST',
      body: payload.toJson(),
      fromJson: (json) => Contract.fromJson(json),
    );
  }

  Future<BlockchainVerificationResult> verifyContractPdf({
    required int id,
    required Uint8List fileBytes,
    String? token,
  }) async {
    final encoded = base64Encode(fileBytes);
    return ApiClient.request<BlockchainVerificationResult>(
      path: '${ApiConfig.contracts}/$id/verify-pdf',
      method: 'POST',
      token: token,
      body: {'fileBase64': encoded},
      fromJson: (json) => BlockchainVerificationResult.fromJson(json),
    );
  }
}
