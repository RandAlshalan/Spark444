import 'package:google_maps_webservice/places.dart';

class LocationService {
  final String apiKey;
  late GoogleMapsPlaces places;

  LocationService({required this.apiKey}) {
    places = GoogleMapsPlaces(apiKey: apiKey);
  }

  /// Fetches a list of location suggestions based on a query.
  Future<List<Prediction>> getSuggestions(String query) async {
    if (query.isEmpty) {
      return [];
    }

    // Call the Google Places Autocomplete API
    final response = await places.autocomplete(
      query,
      language: 'en',
    );

    if (response.status == 'OK') {
      return response.predictions;
    } else {
      // Handle API errors
      print('Places API error: ${response.errorMessage}');
      return [];
    }
  }
}
