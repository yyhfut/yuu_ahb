/////////////////////////////////////////////////////////////////////////////////////
// Copyright 2020 seabeam@yahoo.com - Licensed under the Apache License, Version 2.0
// For more information, see LICENCE in the main folder
/////////////////////////////////////////////////////////////////////////////////////
`ifndef GUARD_YUU_AHB_MASTER_ADAPTER_SV
`define GUARD_YUU_AHB_MASTER_ADAPTER_SV

// Class: yuu_ahb_reg_extension
// Register extension for adapter.
class yuu_ahb_reg_extension extends uvm_object;
  // Variable: byte_offset
  // Byte address base on register address.
  yuu_ahb_addr_t    byte_offset;

  // Variable: data
  // Register payload.
  yuu_ahb_data_t    data[];

  // Variable: size
  // User defined HSIZE.
  yuu_ahb_size_e    size;

  // Variable: burst
  // User defined HBURST.
  yuu_ahb_burst_e   burst = yuu_ahb_pkg::INCR;

  // Variable: prot0
  // User defined HPROT[0].
  yuu_ahb_prot0_e   prot0 = DATA_ACCESS;

  // Variable: prot1
  // User defined HPROT[1].
  yuu_ahb_prot1_e   prot1 = PRIVILEGED_ACCESS;

  // Variable: prot2
  // User defined HPROT[2].
  yuu_ahb_prot2_e   prot2 = NON_BUFFERABLE;

  // Variable: prot3
  // User defined HPROT[3].
  yuu_ahb_prot3_e   prot3 = NON_CACHEABLE;

  // Variable: master
  // User defined HMASTER.
  bit[3:0]          master;

  // Variable: lock
  // User defined HMASTLOCK.
  bit               lock;

  // Variable: nonsec
  // User defined HNONSEC.
  yuu_ahb_nonsec_e  nonsec = NON_SECURE;

  // Variable: excl
  // User defined HEXCL.
  yuu_ahb_excl_e    excl = NON_EXCLUSIVE;

  `uvm_object_utils(yuu_ahb_reg_extension)

  // Function: new
  // Constructor of object.
  function new(string name="yuu_ahb_reg_extension");
    super.new(name);
  endfunction
endclass : yuu_ahb_reg_extension


// Class: yuu_ahb_master_adapter
// AHB register adapter.
class yuu_ahb_master_adapter extends uvm_reg_adapter;
  // Variable: cfg
  // AHB agent configuration object.
  yuu_ahb_master_config cfg;

  `uvm_object_utils(yuu_ahb_master_adapter)

  extern function                   new(string name="yuu_ahb_master_adapter");
  extern function uvm_sequence_item reg2bus(const ref uvm_reg_bus_op rw);
  extern function void              bus2reg(uvm_sequence_item bus_item, ref uvm_reg_bus_op rw);
endclass : yuu_ahb_master_adapter

// Function: new
// Constructor of object.
function yuu_ahb_master_adapter::new(string name="yuu_ahb_master_adapter");
  super.new(name);
endfunction

// Function: reg2bus
// UVM built-in method. Transfer AHB transaction to pin level information.
function uvm_sequence_item yuu_ahb_master_adapter::reg2bus(const ref uvm_reg_bus_op rw);
  yuu_ahb_master_item reg_item = yuu_ahb_master_item::type_id::create("reg_item");
  uvm_reg_item item = get_item();

  if (cfg == null)
    `uvm_fatal("reg2bus", "Adapter can't get configuration")

  reg_item.cfg = cfg;
  if (item.extension == null) begin
    reg_item.randomize() with {
      direction == {rw.kind == UVM_READ} ? READ : WRITE;
      len == 0;
      start_address == rw.addr;
      data[0] == rw.data;
      size == $clog2(cfg.data_width/8);
      burst == SINGLE;
      prot0 == DATA_ACCESS;
      prot1 == PRIVILEGED_ACCESS;
      prot2 == NON_BUFFERABLE;
      prot3 == NON_CACHEABLE;
      prot3_emt == NON_MODIFIABLE;
      prot4_emt == NO_LOOKUP;
      prot5_emt == NO_ALLOCATE;
      prot6_emt == NON_SHAREABLE;
      lock == 1'b0;
      nonsec == NON_SECURE;
      excl == NON_EXCLUSIVE;
      idle_delay == 0;
    };
  end
  else begin
    yuu_ahb_reg_extension ext;
    
    if (!$cast(ext, item.extension))
      `uvm_error("reg2bus", "Invalid AHB register extension type")
    if (ext.byte_offset > cfg.data_width/8-1)
      `uvm_warning("reg2bus", "It may accessed the address out of current register")

    reg_item.randomize() with {
      direction == (rw.kind == UVM_READ) ? READ : WRITE;
      start_address == rw.addr+ext.byte_offset;
      if (data.size() == 0) {
        len == 0;
        data[0] == rw.data;
      }
      else {
        foreach (data[i]) {
          data[i] == ext.data[i];
          busy_delay[i] == 0;
        }
      }

      size == ext.size;
      burst == ext.burst;
      prot0 == ext.prot0;
      prot1 == ext.prot1;
      prot2 == ext.prot2;
      prot3 == ext.prot3;
      master == ext.master;
      lock == ext.lock;
      nonsec == ext.nonsec;
      excl == ext.excl;
      idle_delay == 0;
    };
  end

  return reg_item;
endfunction

// Function: bus2reg
// UVM built-in method. Transfer pin level information to AHB transaction.
function void yuu_ahb_master_adapter::bus2reg(uvm_sequence_item bus_item, ref uvm_reg_bus_op rw);
  yuu_ahb_master_item item;

  if (!$cast(item, bus_item))
    `uvm_fatal("bus2reg", "Provided bus_item is not of the correct type(yuu_ahb_master_item)")

  rw.kind = int'(item.direction) ? UVM_WRITE : UVM_READ;
  rw.addr = item.address[0];
  rw.data = item.data[0];
  rw.status = (item.response[0] == OKAY) ? UVM_IS_OK : UVM_NOT_OK;
endfunction

`endif