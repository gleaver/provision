#!/usr/bin/env python

import io
import fcntl
import struct
import contextlib
import time

class I2C:
  I2C_SLAVE = 0x0703

  def __init__(self, bus, address):
    self.bus = bus
    self.address = address

  @contextlib.contextmanager
  def connect(self, spec):
    fd = io.open(f'/dev/i2c-{self.bus}', spec, buffering=0)
    fcntl.ioctl(fd, self.I2C_SLAVE, self.address)
    yield fd
    fd.close()

  def read(self, count):
    with self.connect('rb') as conn:
      data = struct.unpack('B' * count, conn.read(count))
    return data

  def write(self, *args):
    with self.connect('wb') as conn:
      conn.write(struct.pack('B' * len(args), *args))


class HTU21DF(I2C):
  INTERVAL = 0.05

  @property
  def temperature(self):
    self.write(0xe3)
    time.sleep(self.INTERVAL)
    raw = self.read(3)
    s_temp = ((raw[0] << 8) + raw[1]) & ~0x03
    return -46.85 + ( (175.72 * s_temp) / (2**16) )

  @property
  def humidity(self):
    self.write(0xe5)
    time.sleep(self.INTERVAL)
    raw = self.read(3)
    s_temp = ((raw[0] << 8) + raw[1]) & ~0x0f
    return -6.0 + ( (125.0 * s_temp) / (2**16) )


class ADS1115(I2C):
  """
  http://www.ti.com/lit/ds/symlink/ads1115.pdf
  """
  INTERVAL = 0.05

  CONVERSION_REGISTER = 0x00
  CONFIG_REGISTER = 0x01

  OS_NO_CONVERT = 0x00
  OS_CONVERT = 0x01

  MUX_0 = 0x4
  MUX_1 = 0x5
  MUX_2 = 0x6
  MUX_3 = 0x7

  PGA_6_1V = 0x0
  PGA_4_1V = 0x1
  PGA_2_0V = 0x2
  PGA_1_0V = 0x3
  PGA_0_5V = 0x4
  PGA_0_2V = 0x5

  MODE_ONE = 0x1
  DR_128 = 0x4
  COMP_MODE_TRAD = 0x0
  COMP_POL_LOW = 0x0
  COMP_LAT_NO = 0x0
  COMP_QUE_DISABLE = 0x3


  def configure(self, *, os=OS_NO_CONVERT, mux=MUX_0, pga=PGA_6_1V):
    self.write(
      self.CONFIG_REGISTER,
      (os << 7) | (mux << 4) | (pga << 1) | (self.MODE_ONE << 0),
      (self.DR_128 << 5) | (self.COMP_MODE_TRAD << 4) | (self.COMP_POL_LOW << 3) | (self.COMP_LAT_NO << 2) | (self.COMP_QUE_DISABLE << 0),
    )

  def convert(self, index):
    self.configure(
      os=self.OS_CONVERT,
      mux=[self.MUX_0, self.MUX_1, self.MUX_2, self.MUX_3][index],
    )
    config, timeout = self.read(2), 10
    while not (config[0] & (self.OS_CONVERT << 7)) and timeout > 0:
      sleep(0.001)
      config, timeout = self.read(2), timeout - 1

    self.write(self.CONVERSION_REGISTER)
    raw = self.read(2)
    return (raw[0] << 8) | raw[1]


class Moisture(ADS1115):
  def __init__(self, bus, address, offset):
    super().__init__(bus, address)
    self.offset = offset

  @property
  def value(self):
    return self.convert(self.offset)


class Humidity(HTU21DF):
  def __init__(self, bus, address, offset):
    super().__init__(bus, address)

  @property
  def value(self):
    return self.humidity


class Temperature(HTU21DF):
  def __init__(self, bus, address, offset):
    super().__init__(bus, address)

  @property
  def value(self):
    return self.temperature


class Sensor:
  """
  name type bus address offset

  type = moisture, humidity, temperature
  """
  def __init__(self, path):
    self.metrics = {}
    factory = {
      'moisture': Moisture,
      'humidity': Humidity,
      'temperature': Temperature,
    }
    for name, type, bus, address, offset, tags in self.parse_lines(path):
      if type in factory:
        self.metrics[name] = (factory[type](
          int(bus, 16),
          int(address, 16),
          int(offset, 16),
        ), type, tags)

  def parse_lines(self, path):
    with open(path) as f:
      for line in f.readlines():
        tokens = line.strip().split(' ')
        if len(tokens) == 6:
          yield tokens

  @property
  def values(self):
    return { name: metric.value for name, (metric, type, tags) in self.metrics.items() }

  @property
  def prometheus_values(self):
    for name, (metric, type, tags) in self.metrics.items():
      all_tags = ','.join([f'name="{name}"', tags])
      yield f"{type}{{{all_tags}}} {metric.value}"
    

if __name__ == '__main__':
  import sys
  config = sys.argv[1]
  outfile = sys.argv[2] if len(sys.argv) > 2 else None

  sensor = Sensor(config)

  if outfile is None:
    for metric, value in sensor.values.items():
      print(f"{metric}: {value}")
  else:
    with open(outfile, "w") as f:
      for line in sensor.prometheus_values:
        f.write('# HELP halp\n')
        f.write('# TYPE gauge\n')
        f.write(f"{line}\n")

