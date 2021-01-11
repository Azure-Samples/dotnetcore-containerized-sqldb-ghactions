using System;
using System.ComponentModel.DataAnnotations;

namespace DotNetCoreSqlDb.Models
{
    public class VersionInfo
    {
        public const string VersionInfoSection = "VersionInfo";
        public string Number {get; set;}
        public string Date {get; set;}
    }
}

