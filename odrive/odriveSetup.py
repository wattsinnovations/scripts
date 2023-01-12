import time
import odrive

def setupConnection(): 
    odrv0 = odrive.find_any()
    print('WattsODriveSetup v1.0.3 - trial version')
    print('Found ODrive0:', odrv0.serial_number)
    return

def eraseODriveConfig():
    odrv0 = odrive.find_any()
    # without try/except the odrive disconnect will crash the script
    try:
        odrv0.erase_configuration()
        print('Erasing configuration')
    except:
        pass
    # if(!odrv0):
    #     print('odrv0 not found')
    return

def setVariables(): 
    odrv0 = odrive.find_any()
    print('Setting variables...')
    odrv0.axis0.motor.config.pole_pairs = 21
    odrv0.axis0.motor.config.torque_constant = 0.0955
    odrv0.axis0.motor.config.current_lim = 500.0
    odrv0.axis0.encoder.config.cpr = 768
    odrv0.axis0.controller.config.pos_gain = 60
    odrv0.axis0.controller.config.vel_gain = 0.12
    odrv0.axis0.controller.config.vel_integrator_gain = 0.75
    odrv0.axis0.controller.config.enable_vel_limit = True
    odrv0.axis0.controller.config.enable_overspeed_error = False
    odrv0.axis0.controller.config.anticogging.anticogging_enabled = False
    odrv0.axis0.encoder.config.use_index = True
    odrv0.axis0.motor.config.pre_calibrated = True
    odrv0.axis0.config.calibration_lockin.accel = -20
    odrv0.axis0.config.calibration_lockin.vel = -40.0
    odrv0.axis0.config.calibration_lockin.ramp_distance = -3.1415927410
    odrv0.config.uart_baudrate = 57600
    print('Variables set')
    time.sleep(3)
    return

def calibrateODrive():
    odrv0 = odrive.find_any()
    print('Calibrating ODrive')

    odrv0.axis0.requested_state = 3
    time.sleep(25)

def calibrateEncoder():
    odrv0 = odrive.find_any()
    print('Calibrating Encoder')
    odrv0.axis0.requested_state = 7
    time.sleep(25)
    odrv0.axis0.encoder.config.pre_calibrated = True
    odrv0.axis0.config.startup_encoder_index_search = True

    print('saving configuration & exiting')
    odrv0.save_configuration()

def checkODriveVariables():
    odrv0 = odrive.find_any()

    variablesCorrectlySet = True

    if(odrv0.axis0.motor.config.pole_pairs != 21):
        variablesCorrectlySet = False
    if(odrv0.axis0.motor.config.torque_constant != 0.09549999982118607):
        variablesCorrectlySet = False
    if(odrv0.axis0.motor.config.current_lim != 500.0):
        variablesCorrectlySet = False
    if(odrv0.axis0.encoder.config.cpr != 768):
        variablesCorrectlySet = False
    if(odrv0.axis0.controller.config.pos_gain != 60):
        variablesCorrectlySet = False
    if(odrv0.axis0.controller.config.vel_gain != 0.11999999731779099):
        variablesCorrectlySet = False
    if(odrv0.axis0.controller.config.vel_integrator_gain != 0.75):
        variablesCorrectlySet = False
    if(odrv0.axis0.controller.config.enable_vel_limit != True):
        variablesCorrectlySet = False
    if(odrv0.axis0.controller.config.enable_overspeed_error != False):
        variablesCorrectlySet = False
    if(odrv0.axis0.controller.config.anticogging.anticogging_enabled != False):
        variablesCorrectlySet = False
    if(odrv0.axis0.encoder.config.use_index != True):
        variablesCorrectlySet = False
    if(odrv0.axis0.motor.config.pre_calibrated != True):
        variablesCorrectlySet = False
    if(odrv0.axis0.config.calibration_lockin.accel != -20):
        variablesCorrectlySet = False
    if(odrv0.axis0.config.calibration_lockin.vel != -40.0):
        variablesCorrectlySet = False
    if(odrv0.axis0.config.calibration_lockin.ramp_distance != -3.1415927410125732):
        variablesCorrectlySet = False
    if(odrv0.config.uart_baudrate != 57600):
        variablesCorrectlySet = False
    if(odrv0.axis0.encoder.config.pre_calibrated != True):
        variablesCorrectlySet = False
    if(odrv0.axis0.config.startup_encoder_index_search != True):
        variablesCorrectlySet = False

    if(variablesCorrectlySet == True):
        print('variables match')
    else: 
        print('variables did not match, something is wrong')



def main():
    setupConnection()
    eraseODriveConfig()
    setVariables()
    calibrateODrive()
    calibrateEncoder()
    checkODriveVariables()

main()

