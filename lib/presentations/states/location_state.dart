class LocationState {
  final bool isLoading;
  final bool isListening;
  final String? errorMessage;
  final double? latitude;
  final double? longitude;

  const LocationState({
    this.isLoading = false,
    this.isListening = false,
    this.errorMessage,
    this.latitude,
    this.longitude,
  });

  LocationState copyWith({
    bool? isLoading,
    bool? isListening,
    String? errorMessage,
    double? latitude,
    double? longitude,
  }) {
    return LocationState(
      isLoading: isLoading ?? this.isLoading,
      isListening: isListening ?? this.isListening,
      errorMessage: errorMessage, // not kept: omitting it clears the error
      latitude: latitude ?? this.latitude, // kept when omitted
      longitude: longitude ?? this.longitude,
    );
  }
}
