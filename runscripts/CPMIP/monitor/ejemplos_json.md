# Ejemplos de JSON Generados por el Sistema de Monitoreo

Este documento muestra ejemplos de las estructuras JSON generadas por el sistema de monitoreo del workflow Climate-DT.

## 1. NodeStats (Estadísticas de Pidstat por Nodo)

```json
{
  "Summary": {
    "Cpu_Related": {
      "Total_Cpu_Physical_Cores": 12.5,
      "Job_Cpu_Utilization_Percent": 78.125
    },
    "Memory_Related": {
      "Total_Memory_Bytes": 34359738368,
      "Job_Memory_Of_Node_Percent": 42.5,
      "Job_Memory_Of_Job_Limit_Percent": 85.0
    },
    "Context_Switches": {
      "Total_Voluntary_Per_Second": 1250.5,
      "Total_Involuntary_Per_Second": 45.2
    },
    "Counts": {
      "Process_Count": 48,
      "Filtered_Kernel_Processes_Count": 12
    }
  },
  "Processes": [
    {
      "Pid": "12345",
      "Uid": "1000",
      "Command": "nemo.exe",
      "Cpu_Related": {
        "Cpu_Physical_Cores": 3.5,
        "Cpu_User_Physical_Cores": 3.2,
        "Cpu_System_Physical_Cores": 0.3,
        "Cpu_Guest_Physical_Cores": 0.0,
        "Cpu_Wait_Physical_Cores": 0.1,
        "CPU_Processor_ID": "8"
      },
      "Memory_Related": {
        "Rss_Bytes": 8589934592,
        "Vss_Bytes": 10737418240,
        "Memory_Percent_Of_Node": 10.625,
        "Memory_Percent_Of_Job_Limit": 21.25
      },
      "Paging_Related": {
        "Page_Faults_Minor_Per_Second": 125.5,
        "Page_Faults_Major_Per_Second": 0.2
      },
      "Context_Switches": {
        "Voluntary_Per_Second": 45.8,
        "Involuntary_Per_Second": 2.3
      }
    },
    {
      "Pid": "12346",
      "Uid": "1000",
      "Command": "xios_server.exe",
      "Cpu_Related": {
        "Cpu_Physical_Cores": 2.0,
        "Cpu_User_Physical_Cores": 1.8,
        "Cpu_System_Physical_Cores": 0.2,
        "Cpu_Guest_Physical_Cores": 0.0,
        "Cpu_Wait_Physical_Cores": 0.5,
        "CPU_Processor_ID": "15"
      },
      "Memory_Related": {
        "Rss_Bytes": 4294967296,
        "Vss_Bytes": 5368709120,
        "Memory_Percent_Of_Node": 5.3125,
        "Memory_Percent_Of_Job_Limit": 10.625
      },
      "Paging_Related": {
        "Page_Faults_Minor_Per_Second": 85.2,
        "Page_Faults_Major_Per_Second": 0.1
      },
      "Context_Switches": {
        "Voluntary_Per_Second": 120.3,
        "Involuntary_Per_Second": 1.5
      }
    }
  ],
  "Node_General_Info": {
    "Status": "success",
    "Cpu_Info": {
      "Threads_Per_Core_Count": 2,
      "Cores_Per_Socket_Count": 16,
      "Sockets_Count": 2,
      "Total_Physical_Cores_Count": 32,
      "Model": "Intel(R) Xeon(R) Gold 6130 CPU @ 2.10GHz"
    },
    "Memory_Info": {
      "Total_Bytes": 137438953472,
      "Used_Bytes": 68719476736,
      "Free_Bytes": 34359738368,
      "Available_Bytes": 51539607552,
      "Used_Percent": 50.0
    },
    "Uptime_Raw": "15 days, 8:23:45",
    "Load_Average": {
      "Min_1": 12.5,
      "Min_5": 11.8,
      "Min_15": 10.2
    }
  }
}
```

## 2. JobMetadata (Metadatos de SLURM - scontrol)

```json
{
  "Job_Id": "12345678",
  "Job_Name": "climate_simulation_run1",
  "Partition": "compute",
  "Account": "climate_project",
  "User_Id": "user123",
  "Quality_Of_Service": "normal",
  "State": "RUNNING",
  "Exit_Code": "0:0",
  "Allocated_Node_List": {
    "Nodes": [
      "node001",
      "node002",
      "node003",
      "node004"
    ],
    "Count": 4
  },
  "Alloc_Node": {
    "Node": "login01",
    "Session_Id": "54321"
  },
  "Timing_Info": {
    "Submit_Time_ISO": "2025-11-24T10:30:00",
    "Start_Time_ISO": "2025-11-24T10:35:00",
    "Estimated_End_Time_ISO": "2025-11-24T22:35:00",
    "Actual_End_Time_ISO": "N/A",
    "Run_Time_Seconds": 7200,
    "Elapsed_Time_Seconds": 7200
  },
  "Resource_Info": {
    "Num_CPUs_Count": 128,
    "Num_Tasks_Count": 64,
    "CPUs_Per_Task_Count": 2,
    "Num_Nodes_Count": 4
  },
  "Tres_Allocated": {
    "Cpu_Count": 128,
    "Mem_Bytes": 549755813888,
    "Node_Count": 4,
    "Billing_Count": 128,
    "Energy_Joules": 0.0
  },
  "Files_Info": {
    "Command": "/home/user123/workflow/run_simulation.sh",
    "Working_Directory": "/home/user123/workflow/runs/run1",
    "Std_Error_Path": "/home/user123/workflow/runs/run1/slurm-12345678.err",
    "Std_Output_Path": "/home/user123/workflow/runs/run1/slurm-12345678.out",
    "Batch_Host": "node001"
  },
  "Threads_Per_Core_Count": 2
}
```

## 3. StepStats (Estadísticas por Step - sstat)

```json
{
  "Step_Id": "12345678.0",
  "Memory": {
    "VM": {
      "Max_Bytes": 10737418240,
      "Average_Bytes": 8589934592,
      "Max_Node": "node001",
      "Max_Task": 0,
      "Peak_To_Average_Ratio": 1.25
    },
    "RSS": {
      "Max_Bytes": 8589934592,
      "Average_Bytes": 6871947674,
      "Max_Node": "node001",
      "Max_Task": 0,
      "Peak_To_Average_Ratio": 1.25
    }
  },
  "Memory_Efficiency": {
    "Physical_To_Virtual_Ratio": 0.8,
    "Average_Memory_Utilization": 0.8,
    "Memory_Waste_Percentage": 20.0,
    "Memory_Consistency": 0.8
  },
  "Cpu_Stats": {
    "Total_Tasks_Count": 64,
    "Min_Cpu_Time_Seconds": 7150.5,
    "Min_Cpu_Node": "node002",
    "Min_Cpu_Task": 23,
    "Average_Cpu_Time_Seconds": 7200.0,
    "Cpu_Time_Variation": 0.0069,
    "Total_Cpu_Time_Seconds": 460800.0
  },
  "Cpu_Frequency": {
    "Average_Frequency_KHz": 2100000.0,
    "Requested_Min_Frequency_KHz": "Unknown",
    "Requested_Max_Frequency_KHz": "Unknown",
    "Frequency_Governor": "Performance"
  },
  "Storage_Stats": {
    "Read": {
      "Max_Bytes": 5368709120,
      "Max_Node": "node001",
      "Max_Task": 0,
      "Average_Bytes": 4294967296
    },
    "Write": {
      "Max_Bytes": 10737418240,
      "Max_Node": "node001",
      "Max_Task": 0,
      "Average_Bytes": 8589934592
    }
  },
  "Io_Efficiency": {
    "Read_Write_Ratio": 0.5,
    "Io_Consistency_Read": 0.8,
    "Io_Consistency_Write": 0.8,
    "Total_Io_Bytes": 16106127360
  },
  "Page_Faults": {
    "Max_Count": 125000,
    "Max_Pages_Node": "node001",
    "Max_Pages_Task": 0,
    "Average_Count": 100000,
    "Fault_Rate": 1.25
  },
  "Energy": {
    "Consumed_Joules": 1500000.0,
    "Average_Power_Watts": 208.33
  },
  "Tres_Usage": {
    "In": {
      "Average": {
        "Energy_Joules": 200000.0,
        "Cpu_Time_Seconds": 7200.0
      },
      "Maximum": {
        "Energy_Joules": 250000.0,
        "Cpu_Time_Seconds": 7500.0
      },
      "Minimum": {
        "Energy_Joules": 150000.0,
        "Cpu_Time_Seconds": 7000.0
      },
      "Total": {
        "Energy_Joules": 1500000.0,
        "Cpu_Time_Seconds": 460800.0
      }
    },
    "Out": {
      "Average": {},
      "Maximum": {},
      "Minimum": {},
      "Total": {}
    }
  }
}
```

## 4. AggregatedJobStats (Estadísticas Agregadas del Job)

```json
{
  "Job_Id": "12345678",
  "Memory": {
    "VM": {
      "Max_Bytes": 10737418240,
      "Average_Bytes": 8589934592,
      "Max_Node": "node001",
      "Max_Task": 0,
      "Peak_To_Average_Ratio": 1.25,
      "Total_Across_Steps_Bytes": 85899345920
    },
    "RSS": {
      "Max_Bytes": 8589934592,
      "Average_Bytes": 6871947674,
      "Max_Node": "node001",
      "Max_Task": 0,
      "Peak_To_Average_Ratio": 1.25,
      "Total_Across_Steps_Bytes": 68719476736
    }
  },
  "Memory_Efficiency": {
    "Physical_To_Virtual_Ratio": 0.8,
    "Average_Memory_Utilization": 0.8,
    "Memory_Waste_Percentage": 20.0,
    "Memory_Consistency": 0.8
  },
  "Storage_Stats": {
    "Read": {
      "Max_Bytes": 5368709120,
      "Max_Node": "node001",
      "Max_Task": 0,
      "Average_Bytes": 4294967296,
      "Total_Across_Steps_Bytes": 42949672960
    },
    "Write": {
      "Max_Bytes": 10737418240,
      "Max_Node": "node001",
      "Max_Task": 0,
      "Average_Bytes": 8589934592,
      "Total_Across_Steps_Bytes": 85899345920
    }
  },
  "Io_Efficiency": {
    "Read_Write_Ratio": 0.5,
    "Io_Consistency_Read": 0.8,
    "Io_Consistency_Write": 0.8,
    "Total_Io_Bytes": 16106127360
  },
  "Cpu_Stats": {
    "Total_Tasks_Count": 64,
    "Total_Cpu_Time_Seconds": 460800.0,
    "Average_Cpu_Time_Seconds": 7200.0,
    "Min_Cpu_Time_Seconds": 7150.5
  },
  "Total_Steps_Count": 10,
  "Total_Energy_Joules": 15000000.0
}
```

## 5. Estructura Completa de Monitoreo (Ejemplo combinado)

```json
{
  "metadata": {
    "Job_Id": "12345678",
    "Job_Name": "climate_simulation_run1",
    "State": "RUNNING",
    "Threads_Per_Core_Count": 2,
    "Resource_Info": {
      "Num_CPUs_Count": 128,
      "Num_Tasks_Count": 64,
      "CPUs_Per_Task_Count": 2,
      "Num_Nodes_Count": 4
    }
  },
  "node_stats": {
    "node001": {
      "Summary": {
        "Cpu_Related": {
          "Total_Cpu_Physical_Cores": 12.5,
          "Job_Cpu_Utilization_Percent": 78.125
        },
        "Memory_Related": {
          "Total_Memory_Bytes": 34359738368,
          "Job_Memory_Of_Node_Percent": 42.5,
          "Job_Memory_Of_Job_Limit_Percent": 85.0
        }
      },
      "Processes": [
        {
          "Pid": "12345",
          "Command": "nemo.exe",
          "Cpu_Related": {
            "Cpu_Physical_Cores": 3.5
          }
        }
      ]
    },
    "node002": {
      "Summary": {
        "Cpu_Related": {
          "Total_Cpu_Physical_Cores": 11.8,
          "Job_Cpu_Utilization_Percent": 73.75
        }
      },
      "Processes": []
    }
  },
  "step_stats": [
    {
      "Step_Id": "12345678.0",
      "Memory": {
        "RSS": {
          "Max_Bytes": 8589934592,
          "Average_Bytes": 6871947674
        }
      },
      "Cpu_Stats": {
        "Total_Cpu_Time_Seconds": 460800.0
      },
      "Energy": {
        "Consumed_Joules": 1500000.0
      }
    }
  ],
  "aggregated_stats": {
    "Job_Id": "12345678",
    "Total_Steps_Count": 10,
    "Total_Energy_Joules": 15000000.0,
    "Memory": {
      "RSS": {
        "Max_Bytes": 8589934592,
        "Total_Across_Steps_Bytes": 68719476736
      }
    }
  }
}
```

## Notas Importantes

### Normalización de Unidades

1. **CPU**: Todos los valores de CPU están normalizados a **cores físicos** (no lógicos):
   - `Cpu_Physical_Cores = (valor_pidstat / 100) / Threads_Per_Core`
   - Ejemplo: 400% en sistema con TPC=2 → 2.0 cores físicos

2. **Memoria**: Todas las métricas en **bytes**:
   - `Rss_Bytes`, `Vss_Bytes`, `Max_Bytes`, etc.

3. **Tiempo CPU**: En **segundos**:
   - `Total_Cpu_Time_Seconds`, `Run_Time_Seconds`, etc.

4. **Energía**: En **joules**:
   - `Energy_Joules`, `Consumed_Joules`

5. **Frecuencia CPU**: En **kHz** (kilohertz):
   - `Average_Frequency_KHz`

### Estados del Job

Para trabajos en ejecución (`RUNNING`):
- `Estimated_End_Time_ISO`: contiene el walltime limit
- `Actual_End_Time_ISO`: "N/A"

Para trabajos completados (`COMPLETED`/`FAILED`):
- `Actual_End_Time_ISO`: tiempo real de finalización
- `Estimated_End_Time_ISO`: "N/A"

### Campos Opcionales (total=False)

Algunos TypedDict tienen `total=False`, lo que significa que pueden estar vacíos o contener solo algunos campos:
- `TresAllocated`
- `TresRequested`
- `CpuInfoBlock`
- `NodeGeneralInfo`
