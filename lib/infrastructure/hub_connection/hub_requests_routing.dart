import 'dart:convert';

import 'package:cybear_jinni/domain/devices/abstract_device/device_entity_abstract.dart';
import 'package:cybear_jinni/domain/devices/device/i_device_repository.dart';
import 'package:cybear_jinni/infrastructure/core/gen/cbj_hub_server/hub_client.dart';
import 'package:cybear_jinni/infrastructure/core/gen/cbj_hub_server/protoc_as_dart/cbj_hub_server.pbgrpc.dart';
import 'package:cybear_jinni/infrastructure/generic_devices/generic_blinds_device/generic_blinds_device_dtos.dart';
import 'package:cybear_jinni/infrastructure/generic_devices/generic_boiler_device/generic_boiler_device_dtos.dart';
import 'package:cybear_jinni/infrastructure/generic_devices/generic_light_device/generic_light_device_dtos.dart';
import 'package:cybear_jinni/infrastructure/generic_devices/generic_rgbw_light_device/generic_rgbw_light_device_dtos.dart';
import 'package:cybear_jinni/infrastructure/generic_devices/generic_smart_tv_device/generic_smart_tv_device_dtos.dart';
import 'package:cybear_jinni/infrastructure/objects/enums.dart';
import 'package:cybear_jinni/injection.dart';
import 'package:cybear_jinni/utils.dart';

class HubRequestRouting {
  static Future<void> navigateRequest() async {
    HubRequestsToApp.hubRequestsStream
        .listen((RequestsAndStatusFromHub requestsAndStatusFromHub) {
      if (requestsAndStatusFromHub.sendingType == SendingType.deviceType) {
        final String requestAsString =
            requestsAndStatusFromHub.allRemoteCommands;
        final Map<String, dynamic> requestAsJson =
            jsonDecode(requestAsString) as Map<String, dynamic>;
        final String? deviceTypeAsString =
            requestAsJson['deviceTypes'] as String?;
        if (deviceTypeAsString == null) {
          return;
        }

        final DeviceTypes? deviceType =
            EnumHelper.stringToDt(deviceTypeAsString);

        if (deviceType == null) {
          return;
        }

        late DeviceEntityAbstract deviceEntity;

        switch (deviceType) {
          case DeviceTypes.light:
            deviceEntity =
                GenericLightDeviceDtos.fromJson(requestAsJson).toDomain();
            logger.i('Adding Light device type');
            break;
          case DeviceTypes.rgbwLights:
            deviceEntity =
                GenericRgbwLightDeviceDtos.fromJson(requestAsJson).toDomain();
            logger.i('Adding rgbW light device type');
            break;
          case DeviceTypes.blinds:
            deviceEntity =
                GenericBlindsDeviceDtos.fromJson(requestAsJson).toDomain();
            logger.i('Adding Blinds device type');
            break;
          case DeviceTypes.boiler:
            deviceEntity =
                GenericBoilerDeviceDtos.fromJson(requestAsJson).toDomain();
            logger.i('Adding Boiler device type');
            break;
          case DeviceTypes.smartTV:
            deviceEntity =
                GenericSmartTvDeviceDtos.fromJson(requestAsJson).toDomain();
            logger.i('Adding Smart TV device type');
            break;
          default:
            logger.i('Device type is $deviceType is not supported');
            return;
        }

        getIt<IDeviceRepository>().addOrUpdateDevice(deviceEntity);
      }
    });
  }
}
