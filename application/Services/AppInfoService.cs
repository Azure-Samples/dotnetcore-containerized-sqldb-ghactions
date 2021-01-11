using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Linq;
using System.Threading.Tasks;
using Microsoft.AspNetCore.Mvc;
using DotNetCoreSqlDb.Models;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Options;

namespace DotNetCoreSqlDb.Services
{
    public interface IAppInfoService{
        public VersionInfo Version { get; }
    }
    public class AppInfoService : IAppInfoService
    {
        public VersionInfo Version {get; private set;}
        
        public AppInfoService(IOptions<VersionInfo> versionInfo)
        {
            Version = versionInfo.Value;
        }
    }
}