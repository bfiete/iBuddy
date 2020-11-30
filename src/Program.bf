using System;

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
