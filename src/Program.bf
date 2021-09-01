using System;
using System.Collections;
using System.Diagnostics;

namespace iBuddy
{
	class Program
	{
		[LinkName(.C)]
		public static int Main(String[] args)
		{
			/*Capture capture = scope .();
			capture.Capture();*/

			IBApp ibApp = scope .();
			ibApp.Init();
			ibApp.Run();
			ibApp.Shutdown();

			return 0;
		}
	}
}
