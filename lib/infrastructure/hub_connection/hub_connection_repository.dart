import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:cybear_jinni/domain/hub/hub_entity.dart';
import 'package:cybear_jinni/domain/hub/hub_failures.dart';
import 'package:cybear_jinni/domain/hub/hub_value_objects.dart';
import 'package:cybear_jinni/domain/hub/i_hub_connection_repository.dart';
import 'package:cybear_jinni/infrastructure/core/gen/cbj_hub_server/hub_client.dart';
import 'package:cybear_jinni/injection.dart';
import 'package:cybear_jinni/utils.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter/foundation.dart';
import 'package:injectable/injectable.dart';
import 'package:location/location.dart';
import 'package:multicast_dns/multicast_dns.dart';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:permission_handler/permission_handler.dart'
    as permission_handler;
import 'package:ping_discover_network_forked/ping_discover_network_forked.dart';

@LazySingleton(as: IHubConnectionRepository)
class HubConnectionRepository extends IHubConnectionRepository {
  HubConnectionRepository() {
    if (currentEnv == Env.prod) {
      hubPort = 60055;
    } else {
      hubPort = 50055;
    }
  }

  /// Port to connect to the cbj hub, will change according to the current
  /// running environment
  late int hubPort;

  static HubEntity? hubEntity;

  Future<void> connectWithHub() async {
    try {
      final ConnectivityResult connectivityResult =
          await Connectivity().checkConnectivity();
    } catch (e) {
      logger.i('Cant check connectivity this is probably PC, error: $e');
    }

    final String? wifiBSSID = await NetworkInfo().getWifiBSSID();

    // if (connectivityResult == ConnectivityResult.wifi &&
    //     hubEntity?.hubNetworkBssid.getOrCrash() == wifiBSSID) {
    if (true) {
      if (hubEntity?.lastKnownIp?.getOrCrash() == null) {
        await searchForHub();
      }

      await HubClient.createStreamWithHub(
          hubEntity!.lastKnownIp!.getOrCrash(), hubPort);
      return;
    } else {
      // await HubClient.createStreamWithHub('', 50051);
      // await HubClient.createStreamWithHub('127.0.0.1', 50051);
      logger.i('Test remote pipes');
    }
  }

  @override
  Future<void> closeConnection() {
    // TODO: implement closeConnection
    throw UnimplementedError();
  }

  /// Search device IP by computer Avahi (mdns) name
  Future<String> getDeviceIpByDeviceAvahiName(String mDnsName) async {
    String deviceIp = '';
    final String fullMdnsName = '$mDnsName.local';

    final MDnsClient client = MDnsClient(rawDatagramSocketFactory:
        (dynamic host, int port,
            {bool? reuseAddress, bool? reusePort, int? ttl}) {
      return RawDatagramSocket.bind(host, port, ttl: ttl!);
    });

    // Start the client with default options.
    await client.start();
    await for (final IPAddressResourceRecord record
        in client.lookup<IPAddressResourceRecord>(
            ResourceRecordQuery.addressIPv4(mDnsName))) {
      deviceIp = record.address.address;
      logger.i('Found address (${record.address}).');
    }

    // await for (final IPAddressResourceRecord record
    //     in client.lookup<IPAddressResourceRecord>(
    //         ResourceRecordQuery.addressIPv6(fullMdnsName))) {
    //   logger.i('Found address (${record.address}).');
    // }

    client.stop();

    logger.i('Done.');

    return deviceIp;
  }

  @override
  Future<Either<HubFailures, Unit>> searchForHub() async {
    try {
      final Either<HubFailures, Unit> locationRequest =
          await askLocationPermissionAndLocationOn();

      if (locationRequest.isLeft()) {
        return locationRequest;
      }

      logger.i('searchForHub');
      final String? wifiIP = await NetworkInfo().getWifiIP();

      final String subnet = wifiIP!.substring(0, wifiIP.lastIndexOf('.'));

      logger.i('subnet IP $subnet');

      final Stream<NetworkAddress> stream =
          NetworkAnalyzer.discover2(subnet, hubPort);

      await for (final NetworkAddress address in stream) {
        if (address.exists) {
          logger.i('Found device: ${address.ip}');

          final String? wifiBSSID = await NetworkInfo().getWifiBSSID();
          final String? wifiName = await NetworkInfo().getWifiName();

          if (wifiBSSID != null && wifiName != null) {
            hubEntity = HubEntity(
              hubNetworkBssid: HubNetworkBssid(wifiBSSID),
              networkName: HubNetworkName(wifiName),
              lastKnownIp: HubNetworkIp(address.ip),
            );
            return right(unit);
          }
        }
      }
    } catch (e) {
      logger.w('Exception searchForHub $e');
    }
    return left(const HubFailures.cantFindHubInNetwork());
  }

  @override
  Future<void> saveHubIP(String hubIP) async {
    logger.i('saveHubIP');
  }

  Future<Either<HubFailures, Unit>> askLocationPermissionAndLocationOn() async {
    final Location location = Location();

    bool _serviceEnabled;
    PermissionStatus _permissionGranted;

    int permissionCounter = 0;

    if (kIsWeb) {
      return left(const HubFailures.automaticHubSearchNotSupportedOnWeb());
    }
    if (!Platform.isLinux && !Platform.isWindows) {
      while (true) {
        _permissionGranted = await location.hasPermission();
        if (_permissionGranted == PermissionStatus.denied) {
          _permissionGranted = await location.requestPermission();
          if (_permissionGranted != PermissionStatus.granted) {
            logger.i('Permission to use location is denied');
            permissionCounter++;
            if (permissionCounter > 5) {
              permission_handler.openAppSettings();
            }
            continue;
          }
        }

        _serviceEnabled = await location.serviceEnabled();
        if (!_serviceEnabled) {
          _serviceEnabled = await location.requestService();
          if (!_serviceEnabled) {
            logger.i('Location is disabled');
            continue;
          }
        }
        break;
      }
    }
    return right(unit);
  }
}
