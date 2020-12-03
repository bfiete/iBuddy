using System;
using System.Collections;
using System.Diagnostics;

namespace iBuddy
{
	class Program
	{
		public static int Main(String[] args)
		{
			IBApp ibApp = scope .();
			ibApp.Init();
			ibApp.Run();
			ibApp.Shutdown();

			return 0;
		}
	}
}
