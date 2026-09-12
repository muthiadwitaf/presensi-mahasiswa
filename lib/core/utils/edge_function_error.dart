class EdgeFunctionError {
  const EdgeFunctionError(this.code, this.message);
  final String code;
  final String message;
}

/// Parses the `{success:false, error:{code, message, ...}}` envelope
/// returned by `errorResponse()` in every Supabase Edge Function
/// (see `supabase/functions/_shared/cors.ts`).
EdgeFunctionError parseEdgeFunctionError(dynamic data, {required String fallbackMessage}) {
  final error = data is Map ? data['error'] : null;
  final code = (error is Map ? error['code'] as String? : null) ?? 'ERROR';
  final message = (error is Map ? error['message'] as String? : null) ?? fallbackMessage;
  return EdgeFunctionError(code, message);
}
